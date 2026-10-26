#!/usr/bin/env bash
# Validate the downloaded GGUF models match expected hashes for Qwen3.8-27B
set -euo pipefail

echo "=== Validating Downloaded GGUF Models ==="

MODELS_DIR="/home/celes/ada/models"
EXPECTED_MODELS=(
    "Qwen3.8-27B-UD-IQ3_XXS.gguf"
    "mtp-Qwen3.8-27B-Q4_0.gguf" 
    "Qwen3.8-27B-UD-IQ4_XS.gguf"
)

# Check each model file exists and has a .done file
for model in "${EXPECTED_MODELS[@]}"; do
    echo "Checking: $model"
    if [ -f "$MODELS_DIR/$model" ] && [ -f "$MODELS_DIR/$model.done" ] && [ -f "$MODELS_DIR/$model.sha256" ]; then
        echo "  ✓ File exists and marked complete"
        
        # Validate MD5 checksum (using sha256)
        if sha256sum -c "$MODELS_DIR/$model.sha256" 2>/dev/null; then
            echo "  ✓ Checksum validation passed"
            ls -lh "$MODELS_DIR/$model"
        else
            echo "  ✗ Checksum validation failed for $model"
            exit 1
        fi
    else
        echo "  ✗ Missing file or incomplete download: $model"
        exit 1
    fi
    echo ""
done

echo "✅ All models validated successfully!"
echo ""
echo "=== Model Sizes ==="
for model in "${EXPECTED_MODELS[@]}"; do
    echo "$model: $(du -h "$MODELS_DIR/$model" | cut -f1)"
done