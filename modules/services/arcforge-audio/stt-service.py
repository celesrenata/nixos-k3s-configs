#!/usr/bin/env python3
"""ArcForge host-native STT — faster-whisper, OpenAI-compatible audio API.

Endpoints (Whisper API):
  POST /v1/audio/transcriptions  (multipart: file, model, language, ...)
  POST /v1/audio/translations    (same model serves both; returns transcript)
  GET  /v1/models                (catalog: the configured STT model id)
  GET  /healthz

The `model` form field is accepted but NOT used to pick a model — this node
serves exactly one STT model (whisper-large-v3), so any model id that
prefix-matches the provider node is served. OmniRoute's dynamic provider_nodes
resolve the host; the model id is a catalog label, not a selector.
"""
from __future__ import annotations

import os
import time
from typing import Optional

from fastapi import FastAPI, File, Form, UploadFile
from fastapi.responses import JSONResponse
from faster_whisper import WhisperModel

MODEL_ID = "whisper-large-v3"
MODEL_DIR = os.environ.get("MODEL_DIR", "/var/lib/arcforge-audio/stt-models")
DEVICE = os.environ.get("ARC_FORGE_STT_DEVICE", "cpu")
COMPUTE_TYPE = os.environ.get("ARC_FORGE_STT_COMPUTE", "int8")
BEAM_SIZE = int(os.environ.get("ARC_FORGE_STT_BEAM", "5"))
DEFAULT_LANGUAGE: Optional[str] = os.environ.get("ARC_FORGE_STT_LANG", "") or None
MAX_FILE_BYTES = 512 * 1024 * 1024

app = FastAPI(title="ArcForge STT")
_model = None
_loaded_at = 0.0


def get_model() -> WhisperModel:
    global _model, _loaded_at
    if _model is None:
        path = os.path.join(MODEL_DIR, "faster-whisper-large-v3")
        t0 = time.monotonic()
        _model = WhisperModel(path, device=DEVICE, compute_type=COMPUTE_TYPE)
        _loaded_at = t0
    return _model


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
    model = get_model()
    lang = language or DEFAULT_LANGUAGE
    t0 = time.monotonic()
    segments, info = model.transcribe(
        data,
        language=lang,
        beam_size=BEAM_SIZE,
        vad_filter=True,
    )
    segments_list = list(segments)
    text = " ".join(s.text.strip() for s in segments_list).strip()
    elapsed = time.monotonic() - t0
    out: dict = {
        "text": text,
        "language": getattr(info, "language", lang or "en"),
        "duration": round(getattr(info, "duration", 0.0) or 0.0, 3),
    }
    want_ts = response_format in ("verbose_json", "vtt", "srt") or timestamp_granularities
    if want_ts and response_format == "verbose_json":
        out["segments"] = [
            {
                "id": i,
                "start": round(s.start, 3),
                "end": round(s.end, 3),
                "text": s.text.strip(),
            }
            for i, s in enumerate(segments_list)
        ]
    elif want_ts and response_format == "srt":
        def _srt_ts(sec: float) -> str:
            h, rem = divmod(int(sec), 3600)
            m, s2 = divmod(rem, 60)
            ms = int(round((sec - int(sec)) * 1000))
            return f"{h:02d}:{m:02d}:{s2:02d},{ms:03d}"
        out["_srt"] = "\n".join(
            f"{i + 1}\n{_srt_ts(s.start)} --> {_srt_ts(s.end)}\n{s.text.strip()}\n"
            for i, s in enumerate(segments_list)
        )
    elif want_ts and response_format == "vtt":
        def _vtt_ts(sec: float) -> str:
            h, rem = divmod(int(sec), 3600)
            m, s2 = divmod(rem, 60)
            return f"{h:02d}:{m:02d}:{s2:02d}.{int(round((sec - int(sec)) * 1000)):03d}"
        out["_vtt"] = "WEBVTT\n\n" + "\n".join(
            f"{_vtt_ts(s.start)} --> {_vtt_ts(s.end)}\n{s.text.strip()}\n"
            for s in segments_list
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
    extra = {}
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
    # Our model is en-only, so the "English translation" of any input is its
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
