# Gremlin Systems NixOS Flake Configuration

A comprehensive NixOS flake configuration managing a 4-node homelab cluster with Intel SR-IOV GPU virtualization, Kubernetes orchestration, and mixed NVIDIA/Intel graphics support.

## Architecture Overview

This configuration manages a high-performance homelab cluster designed for:
- **GPU Virtualization**: Intel Arc iGPU SR-IOV with 7 virtual functions per node
- **Container Orchestration**: K3s Kubernetes cluster with GPU passthrough support
- **High Availability**: Bonded 2.5Gbps networking and UPS power management
- **Monitoring**: Comprehensive system and GPU monitoring with Prometheus/Telegraf
- **Virtualization**: QEMU/KVM with GPU passthrough capabilities

## Systems

| System | IP Address | Graphics | Role | Status |
|--------|------------|----------|------|--------|
| **gremlin-1** | 10.1.1.12 | Intel Arc + NVIDIA | K3s Leader, UPS Server | Active |
| **gremlin-2** | 10.1.1.13 | Intel Arc (NVIDIA planned) | K3s Server | Active |
| **gremlin-3** | 10.1.1.14 | Intel Arc | K3s Server | Active |
| **gremlin-4** | 10.1.1.15 | Intel Arc | K3s Server | Planned |

## Key Features

### Intel SR-IOV GPU Virtualization
- **Patched i915 Driver**: Custom patches for kernel 6.15.7 compatibility
- **7 Virtual Functions**: Per Intel Arc iGPU for container/VM passthrough
- **VFIO Integration**: Automatic VF binding for GPU passthrough
- **Runtime PM Fixes**: Comprehensive stability improvements

### Kubernetes Infrastructure
- **K3s Multi-Master**: High-availability cluster with embedded etcd
- **GPU Support**: NVIDIA Container Toolkit integration
- **CNI Networking**: Flannel with full CNI plugin support
- **Container Runtime**: Containerd with GPU runtime configuration

### Network Architecture
- **Bonded Interfaces**: 802.3ad LACP bonding of dual 2.5Gbps ports
- **Layer 3+4 Hashing**: Optimized traffic distribution
- **Cluster Networking**: Dedicated 10.1.1.0/24 management network

### Power Management
- **UPS Integration**: APC SMX1500 with NUT (Network UPS Tools)
- **Distributed Monitoring**: Server/client architecture across cluster
- **Graceful Shutdown**: Coordinated cluster shutdown on power events

## Usage

### Standard Operations

Deploy to specific systems:
```bash
# Deploy to individual nodes
sudo nixos-rebuild switch --flake .#gremlin-1
sudo nixos-rebuild switch --flake .#gremlin-2
sudo nixos-rebuild switch --flake .#gremlin-3
sudo nixos-rebuild switch --flake .#gremlin-4

# Update flake inputs
nix flake update

# Build without switching (testing)
sudo nixos-rebuild build --flake .#gremlin-1
```

### Cluster Reset Mode

For Kubernetes cluster maintenance and reset operations:
```bash
# Enter reset mode (disables K3s and monitoring)
sudo nixos-rebuild switch --flake .#gremlin-1-reset
sudo nixos-rebuild switch --flake .#gremlin-2-reset
sudo nixos-rebuild switch --flake .#gremlin-3-reset
sudo nixos-rebuild switch --flake .#gremlin-4-reset

# Perform cluster cleanup operations
# (manual K3s data cleanup, etcd reset, etc.)

# Return to normal operation
sudo nixos-rebuild switch --flake .#gremlin-1
```

### Graphics Configuration Variants

```bash
# Current configurations
sudo nixos-rebuild switch --flake .#gremlin-1      # Intel + NVIDIA
sudo nixos-rebuild switch --flake .#gremlin-2      # Intel only

# Future NVIDIA upgrade for gremlin-2
sudo nixos-rebuild switch --flake .#gremlin-2-nvidia
```

## Repository Structure

```
/etc/nixos/
├── flake.nix                    # Main flake with system definitions
├── flake.lock                   # Locked dependency versions
├── .gitignore                   # Git ignore patterns
│
├── hosts/                       # Host-specific configurations
│   ├── gremlin-1/
│   │   ├── configuration.nix    # System-specific settings
│   │   └── hardware-configuration.nix
│   ├── gremlin-2/
│   ├── gremlin-3/
│   └── gremlin-4/
│
├── modules/                     # Shared system modules
│   ├── common.nix              # Base system configuration
│   ├── boot.nix                # Boot loader and kernel config
│   ├── networking.nix          # Network bonding and SSH
│   ├── virtualisation.nix      # QEMU/KVM and Docker
│   │
│   ├── graphics-intel.nix      # Intel Arc graphics + SR-IOV
│   ├── graphics-nvidia.nix     # NVIDIA + Intel hybrid config
│   ├── i915-sriov-patched.nix  # Patched SR-IOV driver
│   ├── i915-sriov.nix          # Legacy SR-IOV module
│   │
│   ├── kubernetes.nix          # K3s cluster configuration
│   ├── monitoring.nix          # Prometheus/Telegraf monitoring
│   ├── ups.nix                 # UPS power management
│   │
│   ├── iscsi.nix               # iSCSI initiator config
│   ├── remote-build.nix        # Distributed compilation
│   └── rgb.nix                 # RGB lighting control
│
└── overlays/                   # Custom package overlays
    ├── kernel.nix              # Linux 6.15 kernel
    ├── nvidia-container-toolkit.nix
    └── intel-firmware.nix      # Intel firmware overrides
```

## Technical Details

### Kernel Configuration
- **Linux 6.15**: Latest kernel for Meteor Lake support
- **SR-IOV Parameters**: Intel iGPU virtualization enabled
- **VFIO Support**: GPU passthrough capabilities
- **Huge Pages**: 1GB and 2MB huge page support

### Graphics Stack
- **Intel Arc Support**: Full hardware acceleration
- **SR-IOV Patching**: Runtime PM and memory safety fixes
- **NVIDIA Integration**: Hybrid graphics with container support
- **Firmware Management**: Optimized firmware loading

### Container Runtime
- **Containerd**: Primary container runtime
- **GPU Runtimes**: NVIDIA and Intel GPU support
- **CNI Plugins**: Full networking plugin suite
- **CDI Support**: Container Device Interface for GPUs

### Monitoring Stack
- **Node Exporter**: System metrics collection
- **Intel GPU Top**: GPU utilization monitoring
- **Telegraf**: Metrics aggregation and forwarding
- **UPS Monitoring**: Power status and battery metrics

## Setup and Deployment

### Initial Setup
1. **Hardware Configuration**: Copy hardware-configuration.nix from each system
2. **Network Setup**: Configure bonded interfaces and IP addresses
3. **Certificate Installation**: Place CA certificates in `.config/Certificates/`
4. **UPS Configuration**: Set up password files for UPS monitoring

### Deployment Process
1. **Update Dependencies**: `nix flake update`
2. **Build Configuration**: `sudo nixos-rebuild build --flake .#<hostname>`
3. **Deploy Changes**: `sudo nixos-rebuild switch --flake .#<hostname>`
4. **Verify Services**: Check Kubernetes, monitoring, and UPS status

### Cluster Operations
1. **Initialize Cluster**: Deploy gremlin-1 first (cluster leader)
2. **Join Nodes**: Deploy remaining nodes to join cluster
3. **Verify Connectivity**: Check K3s cluster status and GPU availability
4. **Monitor Health**: Verify monitoring and UPS integration

## Troubleshooting

### SR-IOV Issues
- Check VF creation: `cat /sys/devices/pci0000:00/0000:00:02.0/sriov_numvfs`
- Verify VFIO binding: `lspci -k | grep -A3 "VGA\|3D"`
- Monitor driver logs: `journalctl -u i915-sriov-setup`

### Kubernetes Issues
- Check cluster status: `kubectl get nodes`
- Verify GPU resources: `kubectl describe nodes`
- Monitor K3s logs: `journalctl -u k3s`

### Network Issues
- Check bond status: `cat /proc/net/bonding/bond0`
- Verify connectivity: `systemctl status systemd-networkd`
- Test cluster communication: `ping <other-nodes>`

## Security Considerations

- **Firewall**: Disabled for cluster communication (isolated network)
- **SSH Access**: Root login enabled for system management
- **Certificate Management**: Custom CA for internal services
- **UPS Security**: Password-protected UPS monitoring

## Future Enhancements

- **gremlin-4 Deployment**: Complete 4-node cluster
- **NVIDIA Expansion**: Add NVIDIA GPU to gremlin-2
- **Storage Integration**: Distributed storage with GPU acceleration
- **Workload Optimization**: GPU-accelerated container workloads
