#!/usr/bin/env bash
set -euo pipefail

EXO_DIR="/opt/exo"

# Clone or update the repo
if [ ! -d "$EXO_DIR/.git" ]; then
  git clone --branch xpu https://github.com/celesrenata/exo.git "$EXO_DIR"
else
  cd "$EXO_DIR"
  git fetch origin xpu
  git reset --hard origin/xpu
fi

cd "$EXO_DIR"

# Build dashboard if needed
if [ ! -d "dashboard/build" ]; then
  cd dashboard && npm install && npm run build && cd ..
fi

# Run exo
exec uv run exo -vv
