# NVIDIA Device Plugin Solution for NixOS

## The Problem

The NVIDIA device plugin couldn't find the NVML libraries because:
1. NixOS stores NVIDIA libraries in `/run/opengl-driver/lib` (a symlink to Nix store)
2. Kubernetes hostPath volumes don't follow symlinks
3. The device plugin expected libraries in standard locations

## The Solution

### 1. NixOS Configuration (gremlin-1)

Added systemd service in `/etc/nixos/modules/kubernetes.nix`:

```nix
nvidia-libs-setup = {
  description = "Copy NVIDIA libraries to standard location";
  wantedBy = [ "multi-user.target" ];
  before = [ "k3s.service" ];
  serviceConfig = {
    Type = "oneshot";
    RemainAfterExit = true;
    ExecStart = pkgs.writeShellScript "nvidia-libs-setup" ''
      mkdir -p /usr/local/nvidia/lib64
      rm -rf /usr/local/nvidia/lib64/*
      cp -rL /run/opengl-driver/lib/* /usr/local/nvidia/lib64/
    '';
  };
};
```

This copies actual library files (not symlinks) to `/usr/local/nvidia/lib64/` on boot.

### 2. Kubernetes Configuration

**Helm Values** (`nvidia-device-plugin-values.yaml`):
- Set `deviceDiscoveryStrategy: nvml` to use NVIDIA Management Library
- Configured GPU time-slicing (10 virtual GPUs from 1 physical)
- Removed `runtimeClassName: nvidia` (not needed for device plugin itself)

**DaemonSet Patch** (`daemonset-patch.yaml`):
- Mount `/usr/local/nvidia/lib64` from host to `/host-libs` in container
- Set `LD_LIBRARY_PATH=/host-libs` so NVML can find libraries

## Key Insights

1. **Copy, don't symlink**: Kubernetes can't follow symlinks in hostPath volumes
2. **LD_LIBRARY_PATH matters**: Must point to the actual mount path (not a subdirectory)
3. **NixOS is different**: Standard NVIDIA device plugin instructions assume FHS layout

## Result

- ✅ NVIDIA device plugin running
- ✅ 10 GPU slices available (time-slicing working)
- ✅ GPU pods can now schedule and run
