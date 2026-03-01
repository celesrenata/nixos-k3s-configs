# NVIDIA Device Plugin for NixOS K3s

## What This Does

Installs the NVIDIA device plugin for Kubernetes with GPU time-slicing (10 virtual GPUs from 1 physical GPU).

## NixOS Setup (Already Done on gremlin-1)

The NixOS configuration includes a systemd service that copies NVIDIA libraries from `/run/opengl-driver/lib` to `/usr/local/nvidia/lib64/`. This is necessary because:
1. Kubernetes hostPath volumes don't follow symlinks
2. The NVIDIA device plugin expects libraries in standard locations
3. NixOS stores libraries in the Nix store with symlinks

The service is defined in `/etc/nixos/modules/kubernetes.nix` as `nvidia-libs-setup`.

## Installation

Run: `./runmefirst.sh`

This will:
1. Label gremlin-1 as a GPU node
2. Install the NVIDIA device plugin via Helm
3. Patch the daemonset to mount `/usr/local/nvidia/lib64` into the container
4. Set `LD_LIBRARY_PATH=/host-libs` so the device plugin can find NVML libraries
5. Verify GPU resources are available

## Verification

Check GPU capacity:
```bash
kubectl get node gremlin-1 -o jsonpath='{.status.capacity.nvidia\.com/gpu}'
```

Should show: `10` (1 physical GPU × 10 time slices)

## Test

```bash
kubectl run gpu-test --rm -it --restart=Never \
  --image=nvidia/cuda:12.2.0-base-ubuntu22.04 \
  --limits=nvidia.com/gpu=1 \
  -- nvidia-smi
```
