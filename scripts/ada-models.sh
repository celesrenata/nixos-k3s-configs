#!/usr/bin/env bash
# Download the pinned Qwen3.8-27B GGUFs used by the lishuyu.app 84 tok/s recipe
# into /home/celes/ada/models, with sha256 verification.
set -euo pipefail

M=/home/celes/ada/models
mkdir -p "$M"
BASE=https://huggingface.co/unsloth/Qwen3.8-27B-GGUF/resolve/main

get() { # url dest
  local url=$1 dest=$2
  if [ -f "$dest.done" ]; then
    echo "skip $(basename "$dest") (already downloaded)"
    return 0
  fi
  echo "== [$(date)] $(basename "$dest") =="
  curl -fL --retry 5 --retry-delay 3 -C - -o "$dest.part" "$url"
  mv "$dest.part" "$dest"
  sha256sum "$dest" | tee "$dest.sha256"
  touch "$dest.done"
}

get "$BASE/Qwen3.8-27B-UD-IQ3_XXS.gguf" "$M/Qwen3.8-27B-UD-IQ3_XXS.gguf"
get "$BASE/MTP/mtp-Qwen3.8-27B-Q4_0.gguf" "$M/mtp-Qwen3.8-27B-Q4_0.gguf"
get "$BASE/Qwen3.8-27B-UD-IQ4_XS.gguf" "$M/Qwen3.8-27B-UD-IQ4_XS.gguf"

echo "== [$(date)] models ready =="
ls -lh "$M"
