# ClusterJellyfin Worker Pod Layout

## Current Status: ✅ WORKERS READY

All worker pods are running successfully with complete hardware acceleration support.

## Worker Pod Components

### FFmpeg Location & Capabilities
- **Path**: `/usr/lib/jellyfin-ffmpeg/ffmpeg`
- **Version**: 7.1.2-Jellyfin
- **Hardware Acceleration**: ✅ Complete support
  - VAAPI (Intel/AMD)
  - QSV (Intel Quick Sync)
  - CUDA (NVIDIA)
  - Vulkan (cross-platform)
  - OpenCL (cross-platform)
  - DRM (Direct Rendering Manager)

### SSH Configuration
- **Daemon**: Running as PID 1
- **Port**: 22
- **User**: ubuntu (UID 1000)
- **Host Keys**: `/etc/ssh/ssh_host_*` (owned by ubuntu:ubuntu)
- **Config**: `/etc/ssh/sshd_config` (key-based auth only)
- **User Keys**: `/home/jellyfin/.ssh/` (for main→worker communication)

### Container Details
- **Base Image**: ubuntu:24.04
- **Running User**: ubuntu (1000:1000)
- **Security**: Privileged mode (for /dev/dri access)
- **GPU Access**: Intel SR-IOV via privileged + /dev/dri hostPath

## Architecture Flow

```
┌─────────────────┐    SSH    ┌─────────────────┐
│   Jellyfin      │ ────────▶ │   Worker Pod    │
│   Main Pod      │           │                 │
│   (rffmpeg)     │           │   SSH Daemon    │
└─────────────────┘           │   jellyfin-     │
                              │   ffmpeg        │
                              │   (HW Accel)    │
                              └─────────────────┘
```

## Next Steps Required

1. **Main Pod**: Install/configure rffmpeg proxy
2. **Main Pod**: Configure Jellyfin to use rffmpeg instead of local ffmpeg
3. **Integration**: Test distributed transcoding workflow

## Deployment Settings

Current successful deployment:
```bash
helm install jellyfin clusterjellyfin/clusterjellyfin \
  --namespace jellyfin-system \
  --create-namespace \
  --set workers.gpu.enabled=false \
  --set workers.privileged=true
```

## Worker Pod Status
- **jellyfin-clusterjellyfin-workers-0**: ✅ Running
- **jellyfin-clusterjellyfin-workers-1**: ✅ Running  
- **jellyfin-clusterjellyfin-workers-2**: ✅ Running

All workers have unique SSH host keys and are ready for distributed transcoding.
