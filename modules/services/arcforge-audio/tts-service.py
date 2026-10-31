#!/usr/bin/env python3
"""ArcForge host-native TTS — kokoro-onnx (Kokoro v1.0 ONNX), OpenAI-compatible.

Endpoint:
  POST /v1/audio/speech
    JSON { input, voice, model?, response_format?, speed?, format? }
    -> audio/mpeg (mp3), audio/wav, or audio/opus as requested.
  GET  /v1/models
  GET  /healthz

The `model` field is accepted but the node serves the single Kokoro v1.0
checkpoint; the `voice` field selects a kokoro voice. OpenAI stock voice
names (alloy/echo/...) map onto the v1.0 voice set; the v1.0 names
themselves (af_sarah, af_alloy, am_echo, ...) are also accepted.
OmniRoute's dynamic provider_nodes resolve the host; model ids like
"arcforge-tts-12/<voice>" are catalog labels.

The kokoro pipeline is built lazily on first use. espeak-ng (shared lib +
data dir) is provided by the NixOS espeak-ng package via ESPEAK_LIB /
ESPEAK_DATA env vars set by the systemd unit.
"""
from __future__ import annotations

import io
import os
import time
import zipfile

from fastapi import FastAPI
from fastapi.responses import JSONResponse, Response
from pydantic import BaseModel

MODEL_ID = "kokoro-v1.0"
SAMPLE_RATE = 24000
DEFAULT_VOICE = "af_sarah"

# OpenAI stock voices -> Kokoro v1.0 voices (thewh1teagle/kokoro-onnx).
OPENAI_STOCK_VOICES = {
    "alloy": "af_alloy",
    "echo": "am_echo",
    "fable": "bm_fable",
    "onyx": "am_onyx",
    "nova": "af_nova",
    "shimmer": "af_kore",
    "coral": "af_bella",
    "sage": "am_adam",
}

_MODEL = "/var/lib/arcforge-audio/tts-models/kokoro-v1.0.onnx"
_VOICES = "/var/lib/arcforge-audio/tts-models/voices-v1.0.bin"

app = FastAPI(title="ArcForge TTS")
_pipe = None
_pipe_voices: set = set()
_loaded_at = 0.0
_last_error = None


def get_pipe():
    global _pipe, _pipe_voices, _loaded_at, _last_error
    if _pipe is None:
        t0 = time.monotonic()
        from kokoro_onnx import Kokoro
        from kokoro_onnx.config import EspeakConfig

        espeak_config = None
        lib = os.environ.get("ESPEAK_LIB")
        data = os.environ.get("ESPEAK_DATA")
        if lib and data:
            espeak_config = EspeakConfig(lib_path=lib, data_path=data)
        _pipe = Kokoro(_MODEL, _VOICES, espeak_config=espeak_config)
        _pipe_voices = set(_pipe.get_voices())
        _loaded_at = t0
        _last_error = None
    return _pipe


def _normalize_voice(voice: str) -> str:
    v = (voice or DEFAULT_VOICE).strip()
    v = v.replace("_", "-").replace("-", "_") if "-" in v else v
    if v in OPENAI_STOCK_VOICES:
        return OPENAI_STOCK_VOICES[v]
    return v


class SpeechBody(BaseModel):
    input: str
    voice: str = DEFAULT_VOICE
    model: str = MODEL_ID
    response_format: str = "mp3"
    speed: float = 1.0
    format: str | None = None


def _synthesize(text: str, voice: str, speed: float) -> bytes:
    """Return raw wav bytes (16-bit PCM, 24kHz mono)."""
    import numpy as np

    pipe = get_pipe()
    if voice not in _pipe_voices:
        raise ValueError(f"voice {voice} not found in available voices")
    # kokoro-onnx asserts 0.5 <= speed <= 2.0
    speed = min(max(speed, 0.5), 2.0)
    audio, sr = pipe.create(text, voice=voice, speed=speed, lang="en-us")
    a = np.asarray(audio, dtype=np.float32)
    a = np.clip(a, -1.0, 1.0)
    a = (a * 32767).astype("int16")
    data_bytes = a.tobytes()
    header = _wav_header(len(data_bytes))
    return header + data_bytes


def _wav_header(data_bytes: int) -> bytes:
    import struct

    return b"RIFF" + struct.pack("<I", 36 + data_bytes) + b"WAVEfmt " + struct.pack(
        "<IHHIIHH", 16, 1, 1, SAMPLE_RATE, SAMPLE_RATE * 2, 2, 16
    ) + b"data" + struct.pack("<I", data_bytes)


def _to_mp3(wav_bytes: bytes) -> bytes | None:
    # pydub is pip-installed with kokoro-onnx; its ffmpeg binary is
    # unavailable on NixOS, so fall back to WAV if mp3 encoding fails.
    try:
        from pydub import AudioSegment  # type: ignore

        seg = AudioSegment.from_wav(io.BytesIO(wav_bytes))
        buf = io.BytesIO()
        seg.export(buf, format="mp3")
        return buf.getvalue()
    except Exception:
        return None


def _to_opus(wav_bytes: bytes) -> bytes | None:
    try:
        import soundfile as sf
        import io as _io

        data, sr = sf.read(_io.BytesIO(wav_bytes))
        buf = _io.BytesIO()
        sf.write(buf, data, sr, format="OGG", engine="soundfile")
        return buf.getvalue()
    except Exception:
        return None


@app.get("/healthz")
def healthz() -> dict:
    return {
        "status": "ok" if _pipe is not None or _last_error is None else "degraded",
        "loaded": _pipe is not None,
        "voices": sorted(_pipe_voices)[:8],
        "last_error": _last_error,
    }


@app.get("/v1/models")
def models() -> dict:
    voices = sorted(_pipe_voices) or [DEFAULT_VOICE]
    return {
        "object": "list",
        "data": [
            {
                "id": f"{MODEL_ID}/{v}",
                "object": "model",
                "created": int(_loaded_at or time.time()),
                "owned_by": "arcforge-tts",
            }
            for v in voices
        ],
    }


@app.post("/v1/audio/speech")
async def speech(body: SpeechBody) -> Response:
    text = (body.input or "").strip()
    if not text:
        return JSONResponse(status_code=400, content={"error": {"message": "input is required"}})
    if len(text) > 4000:
        return JSONResponse(
            status_code=400,
            content={"error": {"message": "input exceeds 4000 chars"}},
        )
    voice = _normalize_voice(body.voice or DEFAULT_VOICE)
    t0 = time.monotonic()
    try:
        wav = _synthesize(text, voice, body.speed)
    except Exception as err:  # noqa: BLE001
        global _last_error
        _last_error = f"{type(err).__name__}: {err}"
        return JSONResponse(
            status_code=502,
            content={"error": {"message": f"tts synthesis failed: {type(err).__name__}: {err}", "code": "upstream_error"}},
        )
    latency = int((time.monotonic() - t0) * 1000)
    fmt = (body.format or body.response_format or "mp3").lower()
    headers = {"X-Latency-Ms": str(latency)}
    if fmt in ("mp3", "mpeg"):
        mp3 = _to_mp3(wav)
        if mp3 is not None:
            return Response(content=mp3, media_type="audio/mpeg", headers=headers)
        # fall through: ship WAV, caller may re-encode
    if fmt in ("opus", "ogg"):
        opus = _to_opus(wav)
        if opus is not None:
            return Response(content=opus, media_type="audio/opus", headers=headers)
    return Response(content=wav, media_type="audio/wav", headers=headers)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", "10200")))
