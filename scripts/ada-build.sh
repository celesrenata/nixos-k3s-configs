#!/usr/bin/env bash
# Build llama.cpp (CUDA, SM89) on gremlin-1 into /home/celes/ada/build.
# Uses a nix develop environment; GPU is never touched here.
set -euo pipefail

export NIXPKGS_ALLOW_UNFREE=1
WORK=/home/celes/ada
LOG=$WORK/build.log
SRC=$WORK/llama.cpp

mkdir -p "$WORK"
echo "== [$(date)] cloning llama.cpp (main) ==" | tee "$LOG"
if [ -d "$SRC/.git" ]; then
  git -C "$SRC" fetch origin main && git -C "$SRC" reset --hard origin/main
else
  git clone --depth 1 https://github.com/ggml-org/llama.cpp "$SRC"
fi
git -C "$SRC" log --oneline -1

echo "== [$(date)] cmake configure ==" | tee -a "$LOG"
(
  nix develop --impure --expr \
    "let pkgs = import <nixpkgs> { config.allowUnfree = true; }; in pkgs.mkShell { packages = [ pkgs.cudaPackages.cudatoolkit pkgs.gcc pkgs.cmake pkgs.ninja ]; }" \
    --command bash -c '
      set -euo pipefail
      cd '"$SRC"'
      
      # Build with explicit CUDA options for SM89
      BUILD_CMD=(
        cmake -B build -G Ninja
        -DGGML_CUDA=ON
        -DGGML_CUDA_ARCH=89  
        -DGGML_NATIVE=OFF
        -DGGML_CUDA_DYNLOAD_CUBLAS=ON
        -DCMAKE_BUILD_TYPE=Release
        -DGGML_CCACHE=ON # Optional: enable ccache for faster rebuilds
      )
      
      echo "Executing: ${BUILD_CMD[*]}"
      "${BUILD_CMD[@]}" 2>&1 | tail -30
      
      echo "Building llama-server..."
      cmake --build build --target llama-server llama-quantize 2>&1 | tail -10
      
      echo "Checking build results..."
      if [ -f ./build/bin/llama-server ]; then
        echo "SUCCESS: llama-server built"
        ./build/bin/llama-server --version
      else
        echo "ERROR: llama-server was not built"
        ls -la build/bin/
        exit 1
      fi
    '
) 2>&1 | tee -a "$LOG"

echo "== [$(date)] done ==" | tee -a "$LOG"
ls -la "$SRC/build/bin/llama-server" || echo "Binary not found"
