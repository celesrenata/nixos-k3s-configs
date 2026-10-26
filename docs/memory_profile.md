# GPU Memory Profiling Report

## Current State (as of 2026-10-20)

### GPU Configuration
- Device: NVIDIA GeForce RTX 4070 Ti SUPER
- Total Memory: 16376 MB
- Used: 14720 MB
- Free: 1656 MB
- Utilization: 0%

### Model Deployment (Current)
- Name: qwen3.8:27b-q3-code48k
- Size: 12,942,730,853 bytes (12.9 GB)
- VRAM Estimate: 12,942,730,853 bytes (12.9 GB)
- Quantization Level: Q3_K_L
- Context Length: 8192
- Parameters: 27.3B
- Runner: llamacpp

## Memory Analysis
The current deployment uses approximately 14.7 GB out of 16.4 GB of total GPU memory.
This is consistent with a 27.3B parameter model quantized to Q3_K_L precision (~13-14 GB with KV cache).

This leaves approximately 1.65 GB of VRAM headroom for additional operations.
This is adequate for speculative decoding (MTP) that requires additional memory for draft models,
but requires careful quantization strategy for the base model to stay within limits.

## Next Steps for Quantization Strategy
Based on current usage and memory constraints:
1. Target 12-13 GB for model + KV cache (Q3 or Q4 precision)
2. Ensure draft model consumes < 1 GB
3. Reserve 1.5+ GB headroom for temporary buffers and metadata