#!/usr/bin/env python3
"""ArcForge host-native TTS — kokoro-onnx (Kokoro-82M), OpenAI-compatible.

Endpoint:
  POST /v1/audio/speech
    JSON { input, voice, model?, response_format?, speed?, format? }
    -> audio/mpeg (mp3), audio/wav, or audio/opus as requested.
  GET  /v1/models
  GET  /healthz

The `model` field is accepted but the node serves the single Kokoro-82M
checkpoint; the `voice` field selects a kokoro voice (e.g. "en-us-amy").
OmniRoute's dynamic provider_nodes resolve the host; model ids like
"arcforge-tts-12/en-us-amy" are catalog labels.
"""
from __future__ import annotations

import io
import os
import time
import zipfile

from fastapi import FastAPI
from fastapi.responses import JSONResponse, Response
from pydantic import BaseModel

MODEL_ID = "kokoro-82m"
SAMPLE_RATE = 24000
DEFAULT_VOICE = "en-us-amy"
OPENAI_STOCK_VOICES = {
    "alloy": "en-us-amy",
    "echo": "en-us-ryan",
    "fable": "en-us-kristin",
    "onyx": "en-us-ryan",
    "nova": "en-us-amy",
    "shimmer": "en-us-kristin",
    "coral": "en-us-amy",
    "sage": "en-us-ryan",
}

app = FastAPI(title="ArcForge TTS")
_pipe = None
_loaded_at = 0.0
_last_error = None


def get_pipe():
    global _pipe, _loaded_at, _last_error
    if _pipe is None:
        t0 = time.monotonic()
        from kokoro_onnx import KPipeline

        _pipe = KPipeline(lang="en", device="cpu")
        _loaded_at = t0
        _last_error = None
    return _pipe


class SpeechBody(BaseModel):
    input: str
    voice: str = DEFAULT_VOICE
    model: str = MODEL_ID
    response_format: str = "mp3"
    speed: float = 1.0
    format: str | None = None


def _synthesize(text: str, voice: str) -> bytes:
    """Return raw wav bytes (16-bit PCM, 24kHz mono)."""
    pipe = get_pipe()
    chunks = []
    for _gs, _ps, audio in pipe.synthesize(text, voice=voice):
        # kokoro-onnx returns numpy arrays
        import numpy as np

        a = np.asarray(audio)
        if a.dtype.kind in ("f", "u") and a.dtype.itemsize == 4:
            a = a.astype("float32")
        # kokoro-onnx outputs float32 in [-1, 1]
        if a.dtype == np.float32:
            a = np.clip(a, -1.0, 1.0)
            a = (a * 32767).astype("int16")
        chunks.append(a.tobytes())
    header = _wav_header(len(b"".join(chunks)))
    return header + b"".join(chunks)


def _wav_header(data_bytes: int) -> bytes:
    import struct

    return b"RIFF" + struct.pack("<I", 36 + data_bytes) + b"WAVEfmt " + struct.pack(
        "<IHHIIHH", 16, 1, 1, SAMPLE_RATE, SAMPLE_RATE * 2, 2, 16
    ) + b"data" + struct.pack("<I", data_bytes)


def _to_mp3(wav_bytes: bytes) -> bytes | None:
    # Use pydub if present (pip-installed with kokoro-onnx); else fall back to
    # returning WAV under the mp3 content type is wrong — instead, fall back to
    # a built-in lame-free path: ship WAV and let the caller re-encode. OmniRoute
    # relabels content types; a WAV body is acceptable for audio clients.
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

        import numpy as np

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
        "last_error": _last_error,
    }


@app.get("/v1/models")
def models() -> dict:
    return {
        "object": "list",
        "data": [
            {
                "id": f"{MODEL_ID}/{v}" for v in ("en-us-amy", "en-us-kristin", "en-us-ryan")
            }
            | {"object": "model", "created": int(_loaded_at or time.time()), "owned_by": "arcforge-tts"}
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
    voice = body.voice or DEFAULT_VOICE
    if voice in OPENAI_STOCK_VOICES:
        voice = OPENAI_STOCK_VOICES[voice]
    # Normalize "en_us-amy" -> "en-us-amy"
    voice = voice.replace("_", "-")
    t0 = time.monotonic()
    try:
        wav = _synthesize(text, voice)
    except Exception as err:  # noqa: BLE001
        global _last_error

        _last_error = f"{type(err).__name__}: {err}"
        return JSONResponse(
            status_code=502,
            content={"error": {"message": f"tts synthesis failed: {type(err).__name__}", "code": "upstream_error"}},
        )
    latency = int((time.monotonic() - t0) * 1000)
    fmt = (body.format or body.response_format or "mp3").lower()
    headers = {"X-Latency-Ms": str(latency)}
    if fmt in ("mp3", "mpeg"):
        mp3 = _to_mp3(wav)
        if mp3 is not None:
            return Response(content=mp3, media_type="audio/mpeg", headers=headers)
        # pydub unavailable: fall through to wav body (client decodes WAV)
        return Response(content=wav, media_type="audio/wav", headers=headers)
    if fmt in ("opus", "ogg"):
        opus = _to_opus(wav)
        if opus is not None:
            return Response(content=opus, media_type="audio/ogg", headers=headers)
        return Response(content=wav, media_type="audio/wav", headers=headers)
    # default / wav
    return Response(content=wav, media_type="audio/wav", headers=headers)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=10200, log_level="info")
