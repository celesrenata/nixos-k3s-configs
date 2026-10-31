#!/usr/bin/env bash
# ArcForge audio model fetch — one-shot, idempotent.
# Runs as arcforge-audio. Stores:
#   $STT_ENV   nix store path of the faster-whisper python env
#   $TTS_BASE_ENV nix store path of the tts base env (onnxruntime + espeak-ng)
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
# kokoro-onnx expects the Kokoro-82M checkpoint under $KOKORO_HOME.
if [ ! -f "$TTS_MODELS/Kokoro-82M/kokoro-v1_0.pth" ] && [ ! -f "$TTS_MODELS/kokoro-v1_0.pth" ]; then
  echo "[arcforge-audio-model-fetch] downloading Kokoro-82M (~330MB)"
  "$TTS_BASE_ENV/bin/python3" - <<'PY'
from huggingface_hub import snapshot_download
p = snapshot_download(
    repo_id="hexgrad/Kokoro-82M",
    local_dir="/var/lib/arcforge-audio/tts-models/Kokoro-82M",
    allow_patterns=["kokoro-v1_0.pth", "onnx/*", "*.json", "*.txt"],
)
print("kokoro model ->", p)
PY
fi

# ---------------------------------------------------------------- TTS venv
if [ -x "$TTS_VENV/bin/python" ] && "$TTS_VENV/bin/python" -c "import kokoro_onnx" >/dev/null 2>&1; then
  echo "[arcforge-audio-model-fetch] tts venv already present"
else
  echo "[arcforge-audio-model-fetch] creating tts venv + pip install kokoro-onnx"
  rm -rf "$TTS_VENV"
  "$TTS_BASE_ENV/bin/python3" -m venv --system-site-packages "$TTS_VENV"
  "$TTS_VENV/bin/python" -m pip install --quiet --no-input kokoro-onnx pydub
fi

# ---------------------------------------------------------------- sanity
"$STT_ENV/bin/python3" - <<'PY'
from faster_whisper import WhisperModel
import os
m = WhisperModel(os.environ["MODEL_DIR"] + "/faster-whisper-large-v3", device="cpu", compute_type="int8")
print("[arcforge-audio-model-fetch] whisper model loads OK")
PY

echo "[arcforge-audio-model-fetch] done"
