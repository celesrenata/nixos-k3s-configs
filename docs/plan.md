# Mission Plan: RTX 4070 Ti SUPER Inference Stack

## Executive Summary

This document outlines the implementation plan for creating purpose-built inference profiles for the RTX 4070 Ti SUPER (16GB, SM89) based on the Qwen3.8-27B model. The goal is to deliver three optimized profiles:

1. `ada-reader`: Fast concurrent Qwen3.5-9B reader (4K context)
2. `ada-coder`: Qwen3.8-27B at ~3–3.5 bpw with MTP/speculation  
3. `ada-coder-long`: Up to 200K–262K context with GDN state compression

## Profile Specifications

### Profile 1: `ada-reader` 
- **Base Model**: Qwen3.5-9B (smaller model, faster)
- **Quantization**: Q4_K_M (4-bit)
- **Context Length**: 4K
- **Concurrency**: 4 concurrent requests
- **Target**: >40 tok/s streaming decode throughput
- **Purpose**: Fast, concurrent reading for agents

### Profile 2: `ada-coder`
- **Base Model**: Qwen3.8-27B (full size model)
- **Quantization**: Mixed precision (Q3 + Q4 + KV 4/3-bit)
- **Context Length**: 48K 
- **Concurrency**: 1 concurrent request
- **Target**: 80+ tok/s streaming decode throughput with MTP
- **Features**: MTP speculative decoding (K=3) from llama.cpp research

### Profile 3: `ada-coder-long`
- **Base Model**: Qwen3.8-27B (same as Profile 2)
- **Quantization**: High-efficiency GDN + KV compression 
- **Context Length**: 200K-262K
- **Concurrency**: 1 concurrent request  
- **Target**: 60+ tok/s with 200K+ context using GDN state compression
- **Specialized Features**: 
  - Reduced GDN state footprint with optimized recurrence
  - KV cache engineering (asymmetric precision)
  - DFlash2 draft model with 7-token window

## Implementation Approach

### Phase 1: Investigation & Baseline (Completed)
- Identified target machine: gremlin-1 (10.1.1.12) with RTX 4070 Ti SUPER
- Verified current deployment: `qwen3.8:27b-q3-code48k` (12.9 GB)  
- Analyzed research from 5 specialized sources using component-based approach
- Created profiling tools to measure memory usage
- Generated memory requirement analysis

### Phase 2: Benchmark Foundation (Completed)
- Built a streaming benchmark harness that measures:
  - TTFT (Time to First Token)
  - Decode throughput (tokens/sec)
  - Wall time
  - Prompt eval rate
- Defined fixed test prompts for consistent comparisons

### Phase 3: Component Integration (In Progress) 
#### Task A: Asymmetric KV Caching (Qwen3.8-27B-NV-16GB)
- [x] Identified research source
- [ ] Implement 4/3-bit KV cache format  
- [ ] Test compressed cache strategies

#### Task B: Memory Architecture (Project Den)  
- [x] Identified research source
- [ ] Implement adaptive GPU/host KV transfer
- [ ] Add MTP-aware cache budgeting

#### Task C: NInfer Ada Optimizations
- [x] Identified research source (zedong-peng fork) 
- [ ] Extract SM89-optimized kernel approaches
- [ ] Eliminate duplicate decode weight residency 

#### Task D: Rotated KV Formats (UDPSendToFailed/ninfer-4090)
- [x] Identified research source
- [ ] Implement RK8V4/RK4V4-E8 compressed formats  
- [ ] Validate compression efficiency

#### Task E: Recurrent State Management (Don-Chad/ninfer-3090)
- [x] Identified research source
- [ ] Implement ReplaySSM state replay
- [ ] Test with speculative decoding

### Phase 4: Integration & Deployment
- [ ] Create NixOS/K8s manifests for all three profiles
- [ ] Develop benchmark matrix (profiles × context ladder 4K→262K)  
- [ ] Implement accuracy gates (non-inferior task quality)
- [ ] Create deployment documentation 
- [ ] Final validation against all 15 experiments

## Required Technologies

### Software Stack
1. **llama.cpp**: For fast inference with MTP decoding (primary baseline)
2. **ExLlamaV3**: Alternative high-performance inference approach 
3. **NInfer**: For SM89-optimized kernels
4. **Python**: Benchmarking, memory profiling, validation
5. **CUDA Toolkit 12.x**: For development and profiling
6. **NixOS/Helm/Kubernetes**: For deployment infrastructure  

### Hardware Resources
1. **Target Machine**: gremlin-1 (10.1.1.12) - RTX 4070 Ti SUPER (16GB)
2. **Development Machine**: Local Mac with SSH access
3. **Testing Infrastructure**: Kubernetes cluster for deployment testing  

## Success Criteria

### Metrics Goals
1. **Throughput**: 
   - ada-reader: >40 tok/s 
   - ada-coder: 80+ tok/s with MTP
   - ada-coder-long: 60+ tok/s with 200K context

2. **Accuracy**: Non-inferior task quality vs baseline
3. **Memory Efficiency**: 16GB VRAM constraint maintained
4. **Concurrency**: Proper scheduling of concurrent requests
5. **Latency**: Sub-500ms TTFT on reader, <=1000ms on coder
6. **Scalability**: Long context performance consistent with memory budget

### Validation Mechanisms
1. **Benchmark Matrix**: Full test grid across profiles, contexts, concurrency
2. **Reproducible Evaluation Set**: Fixed prompts to isolate real gains from drift
3. **Accurate Timing**: Instrumentation to measure decode time vs total wall clock
4. **Memory Compliance**: VRAM usage within 16GB limit 
5. **Rollback Mechanism**: Preserve original services during experiment

## Risk Mitigation 

### Technical Risks
- **CUDA Kernel Compatibility**: Ada-optimized kernels may need additional porting work  
- **Memory Fragmentation**: Long contexts may cause fragmentation on 16GB GPU
- **Quantization Artifacts**: Mixed precision may introduce correctness issues
- **Speculative Decoding Overhead**: MTP may slow down short generations

### Operational Risks
- **Host Impact**: Tests may disrupt running services (we'll use existing spare capacity)
- **Service Availability**: GPU scheduling during concurrent tests (limited scope)
- **Deployment Complexity**: Integration with OmniRoute requires careful handling

## Future Expansion Opportunities

1. **Further Optimizations**: 
   - TensorRT integration for maximum throughput
   - Distributed inference across multiple cards  
   - Adaptive context sizing based on content-type complexity

2. **Integration Points**:
   - ComfyUI coexistence (already verified)  
   - OmniRoute agent routing
   - External provider API compliance

3. **Research Directions**:
   - Custom attention kernels for SM89
   - Dynamic quantization based on token importance  
   - Hybrid CPU/GPU KV caching strategies