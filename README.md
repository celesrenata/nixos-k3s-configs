# Gremlin Systems NixOS Flake Configuration

This flake manages the NixOS configurations for all gremlin systems with support for different graphics configurations and reset modes.

## Systems

- **gremlin-1**: Has NVIDIA GPU (10.1.1.12)
- **gremlin-2**: Intel graphics only, will get NVIDIA soon (10.1.1.13)
- **gremlin-3**: Intel graphics only (10.1.1.14)
- **gremlin-4**: Future system, Intel graphics only (10.1.1.15)

## Usage

### Normal Operation

Build and switch to a system configuration:
```bash
sudo nixos-rebuild switch --flake .#gremlin-1
sudo nixos-rebuild switch --flake .#gremlin-2
sudo nixos-rebuild switch --flake .#gremlin-3
sudo nixos-rebuild switch --flake .#gremlin-4
```

### Reset Mode (Kubernetes Cluster Reset)

To put a system in reset mode (disables kubernetes and monitoring, sets etcd.enable = false):
```bash
sudo nixos-rebuild switch --flake .#gremlin-1-reset
sudo nixos-rebuild switch --flake .#gremlin-2-reset
sudo nixos-rebuild switch --flake .#gremlin-3-reset
sudo nixos-rebuild switch --flake .#gremlin-4-reset
```

After running the manual cleanup commands mentioned in the configuration comments, switch back to normal mode:
```bash
sudo nixos-rebuild switch --flake .#gremlin-1
```

### Future: gremlin-2 with NVIDIA

When gremlin-2 gets NVIDIA hardware:
```bash
sudo nixos-rebuild switch --flake .#gremlin-2-nvidia
```

## Structure

```
/etc/nixos/
├── flake.nix                 # Main flake configuration
├── hosts/                    # Host-specific configurations
│   ├── gremlin-1/
│   ├── gremlin-2/
│   ├── gremlin-3/
│   └── gremlin-4/
├── modules/                  # Shared modules
│   ├── common.nix           # Common configuration for all systems
│   ├── graphics-nvidia.nix  # NVIDIA graphics configuration
│   ├── graphics-intel.nix   # Intel graphics configuration
│   ├── kubernetes.nix       # Kubernetes configuration
│   ├── monitoring.nix       # Monitoring configuration
│   └── ...                  # Other existing modules
└── overlays/                # Custom package overlays
```

## Intel SR-IOV Support

This configuration now uses the official `strongtz/i915-sriov-dkms` flake for Intel SR-IOV support instead of custom overlays. The SR-IOV kernel module is automatically included in all systems and provides proper Intel GPU virtualization capabilities.

## Setup Steps

1. Copy hardware-configuration.nix files from each system to their respective host directories
2. Update flake inputs: `nix flake update`
3. Build and test: `sudo nixos-rebuild switch --flake .#<hostname>`

## Reset Mode Details

Reset mode is designed for Kubernetes cluster resets. It:
- Disables the kubernetes.nix and monitoring.nix modules
- Sets `services.etcd.enable = false`
- Keeps all other system functionality intact

This allows you to cleanly reset the cluster state without manually editing configuration files.
