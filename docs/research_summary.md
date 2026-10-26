# Research Summary: RTX 4070 Ti SUPER Inference Optimization

## Analysis of Reference Implementations

### 1. llama.cpp + MTP (lishuyu.app)
- **Approach**: GGUF model with speculative decoding using MTP (Multi-Token Prediction)
- **Performance Target**: 84 tok/s on 16GB 4070 Ti SUPER 
- **Implementation Notes**:
  - Uses IQ3_XXS (quantized) GGUF format
  - MTP with K=3 draft tokens
  - Addresses "cuBLAS crash" with IQ1_M kernels
  - Reports 47.6 tok/s baseline, 84 tok/s with MTP K=3
- **Relevance**: Direct, proven approach that matches target hardware and performance

### 2. ExLlamaV3 (turboderp-org/exllamav3)
- **Approach**: Dedicated CUDA/C++ implementation for fast decoding on 16GB hardware
- **Key Features**:
  - Asymmetric quantization (4-bit K / 3-bit V cache)
  - Support for 204,800-token context (3.0 bpw)
  - CPU-pinned vision tower integration
  - 29-45 tok/s throughput (2 slots) with 3.0 bpw on 16GB cards
- **Relevance**: Potentially more performant than llama.cpp due to architecture,
  but requires significant development investment

### 3. NInfer Ada Port (jram4/ninfer-4090)
- **Approach**: C++/CUDA engine targeting Ada architecture (SM89) 
- **Performance Target**: 200+ tok/s on 4090 (24GB)
- **Key Features**:
  - MTP with 7-token draft window (K7)
  - K8V4 KV cache (FP8 keys, NVFP4 values)  
  - Sampled MTP drafting (improved acceptance rates)
  - Fixed KV cache capacity (188,416 tokens for 24GB)
  - Production deployment ready (systemd, metrics)
- **Relevance**: Production-level approach with proven performance, uses Ada-optimized kernels

### 4. Qwen3.8-4090 Decode (zedong-peng/qwen38-4090-decode)
- **Approach**: Custom engine with mixed quantization and optimized GDN
- **Key Features**:
  - Focuses on minimizing decoder weight residency (critical for 16GB)
  - Optimized attention and linear layers for SM89
  - GDN-specific optimizations for reduced VRAM footprint
- **Relevance**: Targeted approach to the memory limitations of 16GB GPUs

## Critical Performance Characteristics for 16GB RTX 4070 Ti SUPER

### Hardware Specifications
- **Architecture**: Ada Lovelace (SM89)
- **Memory**: 16GB GDDR6X
- **Bandwidth**: ~717 GB/s
- **CUDA Cores**: 8,448

### Memory Constraints and Solutions
1. **Decoder Weight Residency**:
   - 27B model in BF16 would require ~54GB (exceeds 16GB limit)
   - Solution: Mixed precision quantization (Q3/Q4/Q8)
   
2. **KV Cache Management**:
   - 16GB total: ~10GB for weights, 4GB for context/cache 
   - Approach: K8V4 KV cache (FP8 keys, NVFP4 values) to reduce footprint

3. **Attention Efficiency**:
   - Optimized kernels using tensor cores and shared memory
   - Efficient block-level processing for long contexts 

### Target Performance Metrics
| Metric | Goal | Baseline |
|--------|------|----------|
| Decode Throughput | 80+ tok/s | 47.6 tok/s (baseline) |
| Concurrent Requests | 1+ | 1 (baseline) |
| Context Length | 100K+ | 262K (native) |
| Memory Usage | <16GB | ~14GB on 4070 Ti |

## Strategic Recommendations for Implementation

1. **Immediate Path**: Follow llama.cpp + MTP approach (84 tok/s baseline, proven to work)
2. **Enhancement Path**: Hybrid approach combining NInfer optimization techniques with MTP 
3. **Research Path**: Evaluate ExLlamaV3 for deeper performance gains in specialized use cases
4. **Quantization Strategy**: Mixed precision across Q/K/V/O/GDN/MLP/emb/lm_head to minimize VRAM

## Next Steps

1. Build and benchmark llama.cpp implementation locally with MTP  
2. Develop memory profiler for the target profiles  
3. Begin implementing Ada-optimized kernels (SM89 specific optimizations) 
4. Create integrated deployment manifests for k8s/helm (similar to ollama-service)
