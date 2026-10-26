#!/usr/bin/env python3
"""
Memory profiler to monitor VRAM usage on the 4070 Ti SUPER during inference,
to understand current memory constraints and inform quantization decisions.

Can be run standalone for profiling, or as part of benchmark runs.
"""

import subprocess
import time
import json
import sys
import os


def get_gpu_stats():
    """Get current GPU memory stats using nvidia-smi."""
    try:
        result = subprocess.run([
            "nvidia-smi", "--query-gpu=index,name,memory.total,memory.used,memory.free,utilization.gpu", 
            "--format=csv,noheader,nounits"
        ], capture_output=True, text=True, timeout=10)
        
        if result.returncode != 0:
            return None
            
        lines = result.stdout.strip().split('\n')
        if not lines:
            return None
            
        line = lines[0]  # Use first GPU (gremlin-1 typically has one big GPU)
        parts = line.split(', ')
        if len(parts) < 6:
            return None
            
        return {
            "index": parts[0],
            "name": parts[1],
            "memory_total_mb": int(parts[2]),
            "memory_used_mb": int(parts[3]),
            "memory_free_mb": int(parts[4]),
            "gpu_utilization_pct": int(parts[5])
        }
    except Exception as e:
        return None


def measure_model_memory(model_name, base_url="http://10.1.1.12:2701"):
    """
    Simple memory profiling of model loading by checking GPU stats before and after:
    We can't easily measure Ollama loading without direct API introspection,
    so we focus on what we can verify: current GPU utilization and model metadata.
    """
    # Get information from the API 
    try:
        import urllib.request
        import urllib.error
        
        req = urllib.request.Request(f"{base_url}/api/tags")
        with urllib.request.urlopen(req, timeout=10) as resp:
            response = resp.read()
            data = json.loads(response)
            
        # Find our target model
        target_model = None
        for m in data['models']:
            if model_name in m['name']:
                target_model = m
                break
        
        if not target_model:
            return None
            
        return {
            "model": target_model['name'],
            "size": target_model['size'],
            "size_vram": target_model.get('size_vram', target_model['size']),
            "quantization": target_model['details'].get('quantization_level'),
            "context_length": target_model['details'].get('context_length'),
            "parameter_size": target_model['details'].get('parameter_size'),
            "runner": target_model['details'].get('runner'),
        }
    except Exception as e:
        return None


def main():
    print("=== GPU Memory Profile ===")
    
    # Get current GPU stats
    gpu_info = get_gpu_stats()
    if gpu_info:
        print(f"GPU Device: {gpu_info['name']}")
        print(f"Memory Total: {gpu_info['memory_total_mb']} MB")
        print(f"Memory Used: {gpu_info['memory_used_mb']} MB")
        print(f"Memory Free: {gpu_info['memory_free_mb']} MB")
        print(f"GPU Utilization: {gpu_info['gpu_utilization_pct']}%")
        print()
    
    # Get model info from API
    model_info = measure_model_memory("qwen3.8:27b-q3-code48k")
    if model_info:
        print("=== Model Profile ===")
        print(f"Model: {model_info['model']}")
        print(f"Size: {model_info['size']:,} bytes (~{model_info['size']/(1024**3):.1f} GB)")
        print(f"VRAM Estimate: {model_info['size_vram']:,} bytes (~{model_info['size_vram']/(1024**3):.1f} GB)") 
        print(f"Quantization: {model_info['quantization']}")
        print(f"Context: {model_info['context_length']}")
        print(f"Parameters: {model_info['parameter_size']}")
        print(f"Runner: {model_info['runner']}")
    else:
        print("Could not retrieve model information.")
    

if __name__ == "__main__":
    main()