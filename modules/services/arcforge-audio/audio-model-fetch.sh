#!/usr/bin/env bash
# ArcForge audio model fetch — one-shot, idempotent.
# Runs as arcforge-audio. Stores:
#   $STT_ENV        nix store path of the OpenVINO python env
#   $TTS_BASE_ENV   nix store path of the tts base env (onnxruntime + ...)
#   $MODEL_DIR      stt-models root (holds the tokenizer.json + legacy CT2 dir)
#   $HF_HOME        huggingface cache
set -euo pipefail

ROOT=/var/lib/arcforge-audio
STT_MODELS=$ROOT/stt-models
TTS_MODELS=$ROOT/tts-models
TTS_VENV=$ROOT/tts-venv
WHISPER_DIR=$STT_MODELS/faster-whisper-large-v3
# The STT engine is whisper-turbo INT8 on the Arc GPU (OpenVINO IR, ~785MB,
# built locally: encoder+decoder INT8 + config + generation_config). It is NOT
# on Hugging Face, so this fetch only verifies it is present — it does not
# download it. The mel FeatureExtractor is a pure function (no weights), and
# only tokenizer.json is needed for token encode/decode.
OV_STT_DIR=$ROOT/ov/whisper-turbo-int8

echo "[arcforge-audio-model-fetch] starting"

# ---------------------------------------------------------------- STT model
if [ -f "$OV_STT_DIR/openvino_encoder_model.xml" ] && [ -f "$OV_STT_DIR/openvino_decoder_model.xml" ]; then
  echo "[arcforge-audio-model-fetch] whisper-turbo INT8 (OpenVINO) present"
else
  echo "[arcforge-audio-model-fetch] WARNING: whisper-turbo INT8 IR missing at $OV_STT_DIR (built locally; not auto-fetched)"
fi

# Tokenizer (small). Needed for the OpenVINO backend's token id encode/decode.
if [ -f "$WHISPER_DIR/tokenizer.json" ]; then
  echo "[arcforge-audio-model-fetch] whisper tokenizer already present"
else
  echo "[arcforge-audio-model-fetch] downloading whisper tokenizer.json (~2MB)"
  "$STT_ENV/bin/python3" - <<'PY'
from huggingface_hub import hf_hub_download
p = hf_hub_download(
    repo_id="Systran/faster-whisper-large-v3",
    filename="tokenizer.json",
    local_dir="/var/lib/arcforge-audio/stt-models/faster-whisper-large-v3",
)
print("whisper tokenizer ->", p)
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
# Device-agnostic: compile the INT8 IR on the CPU (this one-shot runs as
# arcforge-audio WITHOUT renderD128 access — the STT unit has it) and verify
# the tokenizer + mel FeatureExtractor load. Proves the on-disk IR is valid
# before the STT service starts; does not touch the GPU.
"$STT_ENV/bin/python3" - <<'PY'
import openvino as ov
import tokenizers
from faster_whisper.feature_extractor import FeatureExtractor
core = ov.Core()
core.compile_model(core.read_model("/var/lib/arcforge-audio/ov/whisper-turbo-int8/openvino_encoder_model.xml"), "CPU")
core.compile_model(core.read_model("/var/lib/arcforge-audio/ov/whisper-turbo-int8/openvino_decoder_model.xml"), "CPU")
tok = tokenizers.Tokenizer.from_file("/var/lib/arcforge-audio/stt-models/faster-whisper-large-v3/tokenizer.json")
vocab = tok.get_vocab_size()
assert vocab >= 51000, f"tokenizer looks wrong (vocab={vocab})"
print(f"[arcforge-audio-model-fetch] stt sanity OK: INT8 IR compiles, tokenizer+mel load, vocab={vocab}")
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
