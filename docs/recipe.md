# Qwen3.8-27B MTP 84 tok/s Recipe (RTX 4070 Ti SUPER, 16 GB)

This document captures the complete, validated MTP inference recipe as presented in lishuyu.app's 2026-09-03 blog post, tailored for the RTX 4070 Ti SUPER with 16 GiB VRAM.

## Key Ingredients

### Models

1. **Base Model**: `Qwen3.8-27B-UD-IQ3_XXS.gguf` (~10.9 GB)
   - Quantized using Unsloth's approach (mixed per-layer sensitivity)
   - Contains 3 problematic IQ1_M tensors

2. **Draft Model**: `mtp-Qwen3.8-27B-Q4_0.gguf` (~1.4 GB) 
   - Dedicated MTP draft head
   - Complies with MTP specification

### Critical Fixes

1. **IQ1_M Tensor Fix**
   - Issue: IQ1_M tensors in the base model lack MMQ kernels in precompiled llama.cpp
   - Solution: Rewritten with Q8_0 quantization via `gguf-py` tool
   - File size: increases from 10.9 GB to 11.2 GB

2. **Memory Formula for GDN State**
   - RS = Active Sequences × (Draft Tokens + 1) × 150 MB per sequence
   - 64-layer hybrid model: 48 GDN + 16 attention layers
   - GDN state must remain in GPU memory for performance

### Command Line Parameters

```bash
./llama-server \
  --model /path/to/Qwen3.8-27B-UD-IQ3_XXS.gguf \
  --spec-type draft-mtp \
  --spec-draft-n 3 \
  --spec-draft-n-min 2 \
  --spec-draft-backend-sampling \
  --spec-draft-p-min 0.5 \
  --no-kv-offload \
  --cache-type-k q8_0 \
  --cache-type-v q8_0 \
  --ub 512 \
  --ctx-checkpoints 1 \
  --host 0.0.0.0 --port 2701 \
  --log-verbosity 4 \
  --no-webui \
  --flash-attn on \
  --threads 16
```

### Draft Sweep Results

| Draft Tokens | Decode (tok/s) | Acceptance Rate |
|--------------|----------------|-----------------|
| 2            | 81.4           | 68%             |
| 3            | 83.7           | 59%             |
| 4            | 82.9           | 49%             |
| 5            | 78.2           | 43%             |
| 6            | 73.0           | 37%             |
| 8            | 61.5           | 29%             |

### Performance Characteristics

- **Best Single-Stream**: 84 tok/s with draft 3
- **Concurrency**: 4 concurrent requests = 145 tok/s 
- **Context Window**: 48K tokens with full MTP
- **Power Efficiency**: 220 W sweet spot (52 tok/s, ~14% better energy per token)
- **Memory Usage**: ~15.7 GB total

### Key Optimizations

1. **KV Cache Precision**: q8_0 (not f16) to reduce VRAM pressure
2. **No KV Offload**: All KV and GDN state on GPU for performance
3. **Draft Min Confidence**: 0.5 to balance rate vs throughput
4. **Batch Size**: ub 512 for best performance on Ada architecture

## Hardware Requirements

- RTX 4070 Ti SUPER (16 GB VRAM) 
- CUDA 12.9+ toolkit (requires SM89 support)
- 22+ cores CPU with 32+ GB RAM for building
- nixpkgs environment to build cuda components

## Installation & Deployment

1. Download models from unsloth/Qwen3.8-27B-GGUF
2. Fix IQ1_M tensors using gguf-py tool (if needed)
3. Build llama.cpp with CUDA support
4. Run with MTP flags specified above