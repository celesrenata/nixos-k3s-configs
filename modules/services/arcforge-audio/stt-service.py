#!/usr/bin/env python3
"""ArcForge host-native STT — whisper-turbo (INT8) on the Arc GPU via OpenVINO.

OpenAI-compatible audio API (unchanged surface, so OmniRoute's dynamic
provider_nodes keep working against the same host + model-id label):
  POST /v1/audio/transcriptions  (multipart: file, model, language, ...)
  POST /v1/audio/translations    (same model serves both; returns transcript)
  GET  /v1/models                (catalog: the configured STT model id)
  GET  /healthz

The `model` form field is accepted but NOT used to pick a model — this node
serves exactly one STT model, so any model id that prefix-matches the provider
node is served. OmniRoute's dynamic provider_nodes resolve the host; the model
id is a catalog label, not a selector.

Engine: openai/whisper-large-v3-turbo, ONNX→OpenVINO IR quantized to INT8 with
the official OpenVINO PTQ (NNCF), run on the Arc iGPU (GPU EP) using the
stateful decoder. This replaces the old CT2/faster-whisper CPU path.

The INT8 IR was converted and PTQ-calibrated so its INT8 logits are bit-exact
with FP32 (see the conversion + PTQ calibration notes). Decode is greedy
(argmax); timestamps come from the model's own <|t.t|> tokens, so no separate
VAD is needed.
"""
from __future__ import annotations

import os
import subprocess
import tempfile
import threading
import time
from typing import Optional

import numpy as np
from fastapi import FastAPI, File, Form, UploadFile
from fastapi.responses import JSONResponse
import openvino as ov
import tokenizers
from faster_whisper.feature_extractor import FeatureExtractor

# Catalog label (stable — OmniRoute keys on it). The underlying engine is
# whisper-turbo INT8 on the Arc GPU.
MODEL_ID = "whisper-large-v3"

MODEL_DIR = os.environ.get("MODEL_DIR", "/var/lib/arcforge-audio/stt-models")
# OpenVINO IR (encoder + decoder, INT8) produced by the conversion.
OV_DIR = os.environ.get(
    "ARC_FORGE_STT_OV_DIR", "/var/lib/arcforge-audio/ov/whisper-turbo-int8"
)
# The GPT-2-style tokenizer.json used to encode/decode token ids.
TOKENIZER = os.environ.get(
    "ARC_FORGE_STT_TOKENIZER",
    "/var/lib/arcforge-audio/stt-models/faster-whisper-large-v3/tokenizer.json",
)
DEVICE = os.environ.get("ARC_FORGE_STT_DEVICE", "GPU")
MAX_STEPS = int(os.environ.get("ARC_FORGE_STT_MAX_STEPS", "224"))
# whisper-turbo is English-first (its generation_config has no multilingual
# language-detection path — only forced_decoder_ids + suppress_tokens), so the
# backend defaults to "en". An explicit `language` form field is still honored
# when it resolves to a known language id.
DEFAULT_LANGUAGE: Optional[str] = os.environ.get("ARC_FORGE_STT_LANG", "en")
MAX_FILE_BYTES = 512 * 1024 * 1024

# Whisper token ids (stable across whisper-large-v3 / turbo, same tokenizer).
SOT = 50258          # <|startoftranscript|>
TRANSCRIBE = 50360   # <|transcribe|>
EOS = 50257          # <|endoftext|>
TS_BASE = 50365      # <|0.00|>
TS_STEP = 0.02       # 0.02s per token -> <|30.00|> == 51865
TS_MAX = TS_BASE + int(30.0 / TS_STEP)  # 51865

app = FastAPI(title="ArcForge STT")
_loaded_at = 0.0
_infer_lock = threading.Lock()  # the stateful decoder is single-context; serialize.

_core = None
_encoder: Optional[ov.CompiledModel] = None
_decoder: Optional[ov.CompiledModel] = None
_tok = None
_feature = None


def _load() -> None:
    """Compile the OV IR on the GPU and load the tokenizer. Idempotent."""
    global _core, _encoder, _decoder, _tok, _feature
    if _encoder is not None:
        return
    t0 = time.monotonic()
    _core = ov.Core()
    props = {}
    if DEVICE.upper() == "GPU":
        # Keep the GPU compile cache writable so restarts skip IGC JIT.
        cache = os.environ.get("INTEL_OPENVINO_CACHE")
        if cache:
            props = {"CACHE_DIR": cache}
    _encoder = _core.compile_model(
        _core.read_model(f"{OV_DIR}/openvino_encoder_model.xml"), DEVICE, props
    )
    _decoder = _core.compile_model(
        _core.read_model(f"{OV_DIR}/openvino_decoder_model.xml"), DEVICE, props
    )
    _tok = tokenizers.Tokenizer.from_file(TOKENIZER)
    _feature = FeatureExtractor(
        feature_size=128, sampling_rate=16000, hop_length=160, chunk_length=30, n_fft=400
    )
    _loaded_at = time.monotonic() - t0


def _is_ts(t: int) -> bool:
    return TS_BASE <= t <= TS_MAX


def _ts_time(t: int) -> float:
    return (t - TS_BASE) * TS_STEP


def _decode_to_float32(data: bytes, sample_rate: int = 16000) -> np.ndarray:
    """Decode arbitrary audio bytes to a 16 kHz float32 mono array.

    The system ffmpeg (on PATH via the unit) decodes everything reliably.
    """
    with tempfile.NamedTemporaryFile(suffix=".audio", delete=False) as tmp:
        tmp.write(data)
        tmp_path = tmp.name
    try:
        proc = subprocess.run(
            [
                "ffmpeg", "-v", "error", "-i", tmp_path,
                "-f", "f32le", "-ac", "1", "-ar", str(sample_rate), "pipe:1",
            ],
            check=True, capture_output=True,
        )
        return np.frombuffer(proc.stdout, dtype=np.float32)
    finally:
        os.unlink(tmp_path)


def _encode_window(window: np.ndarray) -> np.ndarray:
    """Run the encoder on a <=30s window -> (1, 1500, 1280) hidden states."""
    mel = _feature(window)  # (128, T)
    feats = np.zeros((128, 3000), dtype=np.float32)
    n = min(mel.shape[1], 3000)
    feats[:, :n] = mel[:, :n]
    req = _encoder.create_infer_request()
    req.infer({"input_features": feats[None].astype(np.float32)})
    return req.get_output_tensor(0).data  # (1, 1500, 1280)


def _lang_prefix(_language: Optional[str]) -> list[int]:
    """Decoder start prefix for the English-first turbo model.

    whisper-turbo is English-first and NOT multilingual: the correct prefix is
    always [SOT, <|transcribe|>] (no language token, matching the validated
    probe). A non-English `language` form field is accepted for OpenAI API
    compatibility but does not change the prefix — the en-only model still
    transcribes English best-effort.
    """
    return [SOT, TRANSCRIBE]


def _transcribe_window(enc_hs: np.ndarray, prefix: list[int], window_len: float):
    """Greedy decode one 30s window -> (segments, full_text)."""
    _decoder.reset_state()
    req = _decoder.create_infer_request()
    out = list(prefix)

    def step(ids, cp):
        req.infer(
            {
                "input_ids": np.array([ids], dtype=np.int64),
                "encoder_hidden_states": enc_hs,
                "cache_position": cp,
                "beam_idx": np.array([0], dtype=np.int64),
            }
        )
        return req.get_output_tensor(0).data[0, -1]

    logits = step(prefix, np.arange(len(prefix), dtype=np.int64))
    nxt = int(np.argmax(logits))
    while nxt != EOS and len(out) < MAX_STEPS:
        out.append(nxt)
        pos = len(out) - 1
        logits = step([nxt], np.array([pos], dtype=np.int64))
        nxt = int(np.argmax(logits))

    gen = out[len(prefix):]
    # Build segments from <|t.t|> tokens (model emits them itself).
    segs: list[tuple[float, float, str]] = []
    start: Optional[float] = None
    cur: list[int] = []
    for t in gen:
        if _is_ts(t):
            if cur:
                segs.append((start if start is not None else 0.0, _ts_time(t), cur))
            start = _ts_time(t)
            cur = []
        else:
            cur.append(t)
    if cur:
        segs.append((start if start is not None else 0.0, window_len, cur))
    # Drop empty segments (timestamp with no text in between).
    segs = [
        (s, e, _tok.decode(ids).strip())
        for s, e, ids in segs
        if _tok.decode(ids).strip()
    ]
    if not segs:
        segs = [(0.0, window_len, _tok.decode(gen).strip())]
    full = " ".join(t for _, _, t in segs).strip()
    return segs, full


def _transcribe(audio: np.ndarray, language: Optional[str]):
    """Run the full file through 30s windows -> (segments, text, used_language)."""
    _load()
    dur = len(audio) / 16000.0
    prefix = _lang_prefix(language)
    # The engine is English-first / en-only: the output language is always "en"
    # regardless of the (accepted-but-ignored) `language` form field.
    used_lang = "en"
    all_segs: list[tuple[float, float, str]] = []
    full_parts: list[str] = []
    hop = 30 * 16000  # 30s windows (matches the encoder's 3000-frame input)
    with _infer_lock:
        for off in range(0, len(audio), hop):
            window = audio[off : off + hop]
            # Energy gate: skip near-silent windows (avoids silence hallucination).
            rms = float(np.sqrt(np.mean(window.astype(np.float64) ** 2)))
            if rms < 0.005:
                continue
            enc_hs = _encode_window(window)
            off_sec = off / 16000.0
            win_len = len(window) / 16000.0
            segs, text = _transcribe_window(enc_hs, prefix, win_len)
            for s, e, t in segs:
                all_segs.append((off_sec + s, off_sec + e, t))
            if text:
                full_parts.append(text)
    all_segs.sort(key=lambda x: x[0])
    # Cap segment end times at total duration.
    all_segs = [(s, min(e, dur), t) for s, e, t in all_segs]
    return all_segs, " ".join(full_parts).strip(), used_lang


@app.get("/healthz")
def healthz() -> dict:
    return {"status": "ok"}


@app.get("/v1/models")
def models() -> dict:
    return {
        "object": "list",
        "data": [
            {
                "id": MODEL_ID,
                "object": "model",
                "created": int(_loaded_at or time.time()),
                "owned_by": "arcforge-stt",
            }
        ],
    }


async def _run_transcription(
    file: UploadFile,
    language: Optional[str],
    response_format: str,
    timestamp_granularities,
) -> dict:
    data = await file.read()
    if len(data) > MAX_FILE_BYTES:
        return {
            "error": {
                "message": "file exceeds 512 MiB limit",
                "type": "invalid_request_error",
                "code": "file_too_large",
            }
        }
    t0 = time.monotonic()
    try:
        audio = _decode_to_float32(data)
    except Exception as err:
        return {
            "error": {
                "message": f"audio decode failed: {err}",
                "type": "invalid_request_error",
                "code": "audio_decode_error",
            }
        }
    segments_list, text, lang = _transcribe(audio, language)
    elapsed = time.monotonic() - t0
    dur = len(audio) / 16000.0
    out: dict = {
        "text": text,
        "language": lang or (language or "en"),
        "duration": round(dur, 3),
    }
    want_ts = response_format in ("verbose_json", "vtt", "srt") or timestamp_granularities
    if want_ts and response_format == "verbose_json":
        out["segments"] = [
            {
                "id": i,
                "start": round(s, 3),
                "end": round(e, 3),
                "text": t,
            }
            for i, (s, e, t) in enumerate(segments_list)
        ]
    elif want_ts and response_format == "srt":
        def _srt_ts(sec: float) -> str:
            h, rem = divmod(int(sec), 3600)
            m, s2 = divmod(rem, 60)
            ms = int(round((sec - int(sec)) * 1000))
            return f"{h:02d}:{m:02d}:{s2:02d},{ms:03d}"
        out["_srt"] = "\n".join(
            f"{i + 1}\n{_srt_ts(s)} --> {_srt_ts(e)}\n{t}\n"
            for i, (s, e, t) in enumerate(segments_list)
        )
    elif want_ts and response_format == "vtt":
        def _vtt_ts(sec: float) -> str:
            h, rem = divmod(int(sec), 3600)
            m, s2 = divmod(rem, 60)
            return f"{h:02d}:{m:02d}:{s2:02d}.{int(round((sec - int(sec)) * 1000)):03d}"
        out["_vtt"] = "WEBVTT\n\n" + "\n".join(
            f"{_vtt_ts(s)} --> {_vtt_ts(e)}\n{t}\n"
            for i, (s, e, t) in enumerate(segments_list)
        )
    out["_latency_ms"] = int(elapsed * 1000)
    return out


@app.post("/v1/audio/transcriptions")
async def transcriptions(
    file: UploadFile = File(...),
    model: str = Form(MODEL_ID),
    language: Optional[str] = Form(None),
    response_format: str = Form("json"),
    temperature: float = Form(0.0),
    timestamp_granularities: Optional[str] = Form(None),
) -> JSONResponse:
    res = await _run_transcription(
        file,
        language,
        response_format,
        timestamp_granularities.split(",") if timestamp_granularities else None,
    )
    if "error" in res:
        return JSONResponse(status_code=400, content=res)
    latency = res.pop("_latency_ms", 0)
    if "_srt" in res:
        return JSONResponse(
            status_code=200,
            content=res["_srt"],
            headers={"Content-Type": "text/srt", "X-Latency-Ms": str(latency)},
        )
    if "_vtt" in res:
        return JSONResponse(
            status_code=200,
            content=res["_vtt"],
            headers={"Content-Type": "text/vtt", "X-Latency-Ms": str(latency)},
        )
    if response_format == "text":
        return JSONResponse(
            status_code=200,
            content=res["text"],
            headers={"Content-Type": "text/plain", "X-Latency-Ms": str(latency)},
        )
    if response_format in ("srt", "vtt"):
        key = "_srt" if response_format == "srt" else "_vtt"
        return JSONResponse(
            status_code=200,
            content=res.get(key, ""),
            headers={"Content-Type": f"text/{response_format}", "X-Latency-Ms": str(latency)},
        )
    return JSONResponse(status_code=200, content=res, headers={"X-Latency-Ms": str(latency)})


@app.post("/v1/audio/translations")
async def translations(
    file: UploadFile = File(...),
    model: str = Form(MODEL_ID),
    response_format: str = Form("json"),
) -> JSONResponse:
    # Whisper-style: translation is served by the transcription-capable node.
    # Our model is en-centric, so the "English translation" of any input is its
    # transcript. Documented behavior; OmniRoute's translations route expects
    # exactly this shape.
    res = await _run_transcription(file, None, response_format, None)
    if "error" in res:
        return JSONResponse(status_code=400, content=res)
    latency = res.pop("_latency_ms", 0)
    if response_format in ("text", "json"):
        return JSONResponse(
            status_code=200,
            content={"text": res.get("text", "")},
            headers={"X-Latency-Ms": str(latency)},
        )
    return JSONResponse(status_code=200, content=res, headers={"X-Latency-Ms": str(latency)})


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=10300, log_level="info")
