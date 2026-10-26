# Component-Based Approach: Cherry-Picking Best Innovations

Based on expert guidance and the validated recipe, this document outlines how we will build upon proven components from several specialized inference engine forks rather than adopting one monolithic solution.

## Core Philosophy
Rather than locking onto a single implementation (like llama.cpp MTP specifically), we will assemble the highest-value components from multiple specialized projects:

1. **NInfer Ada**: Custom Ada kernels, speculative verification algorithms, mixed INT3/INT4 quantization
2. **Rotated KV Formats**: RK8V4, RK4V4-E8, RK2V4-E8 from UDPSendToFailed/ninfer-4090  
3. **Recurrent State Management**: ReplaySSM from Don-Chad/ninfer-3090
4. **Asymmetric KV Caching**: From Qwen3.8-27B-NV-16GB
5. **Memory Management**: From Project Den/den_llama.cpp

## Selected Components

### 1. NInfer Ada (High Priority)
**Contributions:**
- Custom Ada-optimized CUDA kernels
- Speculative verification algorithms  
- Mixed INT3/INT4 quantization techniques
- Language model head screening
- Reduced weight residency (key innovation for 16GB)

**Implementation Priority:** Highest
**Core Value:** Direct Ada architecture optimization and memory savings

### 2. Rotated KV Formats (UDPSendToFailed/ninfer-4090)
**Contributions:**
- RK8V4, RK4V4-E8, RK2V4-E8 compressed KV formats
- E8 lattice codecs for efficient compression
- Rotated KV transform operations

**Implementation Priority:** Medium-High
**Core Value:** Dramatically reduces KV cache memory usage for long contexts

### 3. Recurrent State Management (Don-Chad/ninfer-3090)
**Contributions:**
- ReplaySSM: Reduced state restoration costs
- State-checkpoint management
- Concurrent reader optimization

**Implementation Priority:** Medium
**Core Value:** Enables larger MTP windows without proportional memory growth

### 4. Asymmetric KV Caching (Qwen3.8-27B-NV-16GB)
**Contributions:**
- Asymmetric 4-bit K / 3-bit V cache format
- CPU-pinned vision tower integration
- Host-side prefix caching
- Two-slot continuous batching

**Implementation Priority:** High
**Core Value:** Critical memory efficiency for 16GB limit

### 5. Memory Management Architecture (Project Den)
**Contributions:**
- Adaptive GPU/host KV transfer ring
- MTP-aware cache budgeting
- Long-context memory management

**Implementation Priority:** Medium-High
**Core Value:** Sophisticated memory allocation strategies

## Integration Strategy

### Memory Layout Optimization
Our primary focus will be eliminating "duplicate decode-weight residency" that prevents 16GB deployment from scaling. Based on NInfer insights:
- Consolidate weight loading strategies
- Separate preload/prefill stages from decode 
- Reuse memory regions where possible

### Quantization Approach
Combine the most effective techniques:
1. **Mixed Precision**: INT3/INT4 weights for base model
2. **KV Compression**: Asymmetric 4/3-bit with rotated formats
3. **Precision Tuning**: Layer-specific sensitivity mapping

### Speculative Decoding Enhancement
Incorporate multiple innovations:
1. **Verification Trees**: Improved acceptance rate algorithms
2. **State Replay**: Efficient state transitions during rollback
3. **Window Management**: Adaptive MTP window sizes

## Implementation Timeline (Based on Available Resources)

### Phase 1: Ready Components
With models downloaded and base infrastructure ready:
1. **Asymmetric KV Caching**: Priority #1 (Qwen3.8-27B-NV-16GB) - **Ready for prototyping**
2. **Memory Architecture**: Priority #2 (Project Den) - **Already partially implemented**  

### Phase 2: Advanced Components  
3. **Rotated KV Formats**: Priority #3 (UDPSendToFailed/ninfer-4090) - **Can be prototyped once core components work**
4. **State Management**: Priority #4 (Don-Chad/ninfer-3090) - **Ready once MTP and caching components ready**

### Phase 3: Architecture Optimization
5. **NInfer Kernels**: Priority #5 (NInfer Ada) - **Post-CUDA optimization**

## Key Innovations to Validate

### 1. Reduced Weight Residency 
- Eliminate 4GiB of "duplicate decode weight residency" (NInfer Ada)
- Target 12–13 GB total model occupancy

### 2. KV Format Efficiency
- Demonstrate RK4V4-E8 compressed KV cache on 16GB system
- Implement asymmetric 4-bit keys with 3-bit values

### 3. Recurrent State Optimization  
- Test ReplaySSM for long-context speculative decoding
- Validate memory savings over traditional checkpointing

## Memory Budgeting Framework

| Component | Memory Impact | Priority |
|-----------|---------------|----------|  
| Model Weights | ~12–13 GB | Highest |
| KV Cache | ~2–3 GB | High |
| Draft Model | ~0.5–1.0 GB | Medium |
| Temporary Buffers | ~0.5–1.0 GB | Medium |
| Recurrent State | ~1–2 GB | Medium-High |
| Metadata | ~0.1–0.2 GB | Low |

## Risk Mitigation

- **Compatibility Testing**: Component-by-component validation before integration  
- **Rollback Capability**: Maintain existing baseline for comparison
- **Incremental Deployment**: Stage integration to catch issues early
- **Benchmark Validation**: Continuous measurement to ensure performance targets met

## Success Metrics

### Performance Targets
1. **Throughput**: 80+ tok/s for basic coder profile  
2. **Memory Efficiency**: <16GB total VRAM usage with headroom
3. **Context Capacity**: 100K+ token context with good performance 
4. **Concurrency**: Support for 1–4 concurrent requests

### Validation Protocol
1. **Component-Level Testing**: Individual components with reproducible benchmarks
2. **Integration Testing**: Combined approaches measuring combined benefits
3. **Stress Testing**: Long context and concurrent generation scenarios
4. **Regression Testing**: Verify no performance loss vs baseline

## Next Steps (Immediate)

1. **Verify Base Models**: Confirm IQ1_M tensor issue with Qwen3.8-27B model and fix if needed
2. **Build Benchmark Tools**: Create tools based on the validated recipe to validate throughput/performance
3. **Begin Prototyping Asymmetric KV Caching**: Based on the validated approach from Qwen3.8-27B-NV-16GB
4. **Document Implementation Details**: Record findings for future implementation in NixOS/K8s manifests
5. **Prepare Integration Plan**: Map how components integrate into final 3 profiles

## Resource Constraints

- **Build environment**: CUDA build blocked by complex nix/cuda interaction
- **Model availability**: All required GGUFs (base models + MTP draft) are downloaded and verified
- **Infrastructure**: gremlin-1 available and hosting main Ollama baseline

## Implementation Approach

Given the 16GB VRAM restriction, we'll follow a proven path using documented components:
1. **First, implement the validated basic configuration from lishuyu.app** with proper tensor fixes
2. **Then prototype enhancements** in software components
3. **Later implement CUDA optimizations** once proper environment is restored 

This ensures we meet the performance goals while respecting the project's constraints.