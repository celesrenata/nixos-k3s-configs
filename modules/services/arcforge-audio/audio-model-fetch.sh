#!/usr/bin/env bash
# ArcForge audio model fetch — one-shot, idempotent.
# Runs as arcforge-audio. Stores:
#   $STT_ENV        nix store path of the faster-whisper python env
#   $TTS_BASE_ENV   nix store path of the tts base env (onnxruntime + ...)
#   $MODEL_DIR      where the whisper large-v3 weights live
set -euo pipefail

ROOT=/var/lib/arcforge-audio
STT_MODELS=$ROOT/stt-models
TTS_MODELS=$ROOT/tts-models
TTS_VENV=$ROOT/tts-venv
WHISPER_DIR=$STT_MODELS/faster-whisper-large-v3

echo "[arcforge-audio-model-fetch] starting"

# ---------------------------------------------------------------- STT model
if [ -f "$WHISPER_DIR/model.bin" ]; then
  echo "[arcforge-audio-model-fetch] whisper large-v3 already present"
else
  echo "[arcforge-audio-model-fetch] downloading faster-whisper-large-v3 (~1.6GB)"
  "$STT_ENV/bin/python3" - <<'PY'
from huggingface_hub import snapshot_download
p = snapshot_download(
    repo_id="Systran/faster-whisper-large-v3",
    local_dir="/var/lib/arcforge-audio/stt-models/faster-whisper-large-v3",
    allow_patterns=["model.bin", "*.json", "vocabulary.txt", "*.txt"],
)
print("whisper model ->", p)
PY
fi

# ---------------------------------------------------------------- TTS weights
# kokoro-onnx (thewh1teagle) needs the ONNX model + voices file. These are
# plain files on GitHub releases (no Hugging Face repo for this release tag).
if [ ! -f "$TTS_MODELS/kokoro-v1.0.onnx" ]; then
  echo "[arcforge-audio-model-fetch] downloading kokoro-v1.0.onnx (~310MB)"
  curl -fSL --retry 3 --max-time 900 -o "$TTS_MODELS/kokoro-v1.0.onnx" \
    "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.onnx"
fi
if [ ! -f "$TTS_MODELS/voices-v1.0.bin" ]; then
  echo "[arcforge-audio-model-fetch] downloading voices-v1.0.bin (~27MB)"
  curl -fSL --retry 3 --max-time 300 -o "$TTS_MODELS/voices-v1.0.bin" \
    "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin"
fi

# ---------------------------------------------------------------- TTS venv
# kokoro-onnx + pydub are pip-installed into a writable venv layered over the
# read-only nix base env. (hexgrad `kokoro` cannot be used: it builds espeak
# from source at install time, which fails on this nixpkgs pin.)
if [ -x "$TTS_VENV/bin/python" ] && "$TTS_VENV/bin/python" -c "import kokoro_onnx, pydub" >/dev/null 2>&1; then
  echo "[arcforge-audio-model-fetch] tts venv already present"
else
  echo "[arcforge-audio-model-fetch] creating tts venv + pip install kokoro-onnx pydub audioop-lts"
  rm -rf "$TTS_VENV"
  "$TTS_BASE_ENV/bin/python3" -m venv --system-site-packages "$TTS_VENV"
  "$TTS_VENV/bin/python" -m pip install --quiet --no-input kokoro-onnx pydub audioop-lts
fi

# ---------------------------------------------------------------- sanity
"$STT_ENV/bin/python3" - <<'PY'
from faster_whisper import WhisperModel
import os
m = WhisperModel(os.environ["MODEL_DIR"] + "/faster-whisper-large-v3", device="cpu", compute_type="int8")
print("[arcforge-audio-model-fetch] whisper model loads OK")
PY

"$TTS_VENV/bin/python" - <<'PY'
import kokoro_onnx, pydub
from kokoro_onnx import Kokoro
from kokoro_onnx.config import EspeakConfig
import os, sys
k = Kokoro(
    "/var/lib/arcforge-audio/tts-models/kokoro-v1.0.onnx",
    "/var/lib/arcforge-audio/tts-models/voices-v1.0.bin",
    espeak_config=EspeakConfig(
        lib_path=os.environ.get("ESPEAK_LIB"),
        data_path=os.environ.get("ESPEAK_DATA"),
    ),
)
v = k.get_voices()
assert "af_sarah" in v, f"voices missing: {v[:5]}"
print(f"[arcforge-audio-model-fetch] kokoro pipeline OK ({len(v)} voices)")
PY

echo "[arcforge-audio-model-fetch] done"
