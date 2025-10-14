# Gremlin Systems NixOS Flake Configuration

A comprehensive NixOS flake configuration managing a 4-node homelab cluster with flexible Intel/NVIDIA graphics support, Intel xe SR-IOV GPU virtualization, Kubernetes orchestration, and distributed build capabilities.

## Architecture Overview

This configuration manages a high-performance homelab cluster designed for:
- **Flexible GPU Support**: Configurable Intel Arc and/or NVIDIA graphics per node
- **GPU Virtualization**: Intel Arc xe SR-IOV with 7 virtual functions per node
- **Container Orchestration**: K3s Kubernetes cluster with GPU passthrough support
- **High Availability**: Bonded 2.5Gbps networking and UPS power management
- **Distributed Building**: Cross-node compilation with automatic self-exclusion
- **Monitoring**: Comprehensive system and GPU monitoring with Prometheus/Telegraf
- **Virtualization**: QEMU/KVM with GPU passthrough capabilities

## Systems

| System | IP Address | Graphics | Role | Status |
|--------|------------|----------|------|--------|
| **gremlin-1** | 10.1.1.12 | Intel Arc + NVIDIA RTX 4070 Ti SUPER | K3s Leader, UPS Server | Active |
| **gremlin-2** | 10.1.1.13 | Intel Arc (Rev2 Hardware) | K3s Server | Active |
| **gremlin-3** | 10.1.1.14 | Intel Arc (Rev1 Hardware) | K3s Server | Active |
| **gremlin-4** | 10.1.1.15 | Intel Arc | K3s Server | Planned |

## Key Features

### Flexible Graphics Configuration
- **Modular Design**: Enable/disable Intel and NVIDIA graphics independently
- **Per-Node Configuration**: Different graphics setups per system
- **SR-IOV Support**: Optional Intel xe SR-IOV with 7 virtual functions
- **Hybrid Support**: Intel + NVIDIA coexistence on same node

### Intel xe SR-IOV GPU Virtualization
- **xe Driver**: Uses Intel's xe driver with SR-IOV patches from bbaa-bbaa/i915-sriov-dkms
- **7 Virtual Functions**: Per Intel Arc iGPU for container/VM passthrough
- **VFIO Integration**: Automatic VF binding for GPU passthrough
- **Modprobe Override**: Forces patched xe module over stock kernel module
- **Kernel 6.17**: Latest kernel with Meteor Lake support

### Kubernetes Infrastructure
- **K3s Multi-Master**: High-availability cluster with embedded etcd
- **Leader/Server Architecture**: gremlin-1 initializes cluster, others join at 10.1.1.12:6443
- **GPU Support**: Conditional NVIDIA Container Toolkit and Intel GPU integration
- **CNI Networking**: Flannel with full CNI plugin suite (bridge, host-local, vlan)
- **Container Runtime**: Containerd with adaptive GPU runtime configuration
- **CDI Support**: Container Device Interface for GPU resource management
- **Reset Mode**: Special configurations for cluster maintenance

### Distributed Build System
- **Cross-Node Compilation**: Each node can build on other cluster nodes
- **Self-Exclusion**: Automatic prevention of self-build loops
- **Load Balancing**: 50% CPU utilization limit per remote build

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

# Build using distributed compilation
sudo nixos-rebuild switch --flake .#gremlin-2 --builders ''
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

### Graphics Configuration Examples

The flexible graphics system allows different configurations per node:
```bash
# Current configurations
sudo nixos-rebuild switch --flake .#gremlin-1      # Intel + NVIDIA + SR-IOV
sudo nixos-rebuild switch --flake .#gremlin-2      # Intel + SR-IOV only
sudo nixos-rebuild switch --flake .#gremlin-3      # Intel + SR-IOV only

# Future NVIDIA upgrade for gremlin-2
sudo nixos-rebuild switch --flake .#gremlin-2-nvidia
```

## Repository Structure

```
/etc/nixos/
├── flake.nix                    # Main flake with flexible graphics system
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
│   ├── common.nix              # Base system configuration + SR-IOV service
│   ├── boot.nix                # Boot loader and kernel config
│   ├── networking.nix          # Network bonding and SSH
│   ├── virtualisation.nix      # QEMU/KVM and Docker
│   ├── remote-build.nix        # Distributed compilation
│   │
│   ├── graphics.nix            # Unified flexible graphics module
│   ├── xe-sriov.nix            # Intel xe SR-IOV driver and configuration
│   ├── graphics-nvidia.nix     # Legacy NVIDIA-only config
│   ├── graphics-intel.nix      # Legacy Intel-only config
│   ├── i915-sriov-patched.nix  # Alternative SR-IOV implementation
│   │
│   ├── kubernetes.nix          # K3s cluster configuration
│   ├── monitoring.nix          # Prometheus/Telegraf monitoring
│   ├── ups.nix                 # UPS power management
│   │
│   ├── iscsi.nix               # iSCSI initiator config
│   └── rgb.nix                 # RGB lighting control
│
└── overlays/                   # Custom package overlays
    ├── intel-firmware.nix      # Intel Meteor Lake firmware updates
    ├── kernel.nix              # Linux 6.17 kernel configuration
    └── nvidia-container-toolkit.nix  # NVIDIA container runtime fixes
```

## Technical Details

### Custom Package Overlays
The system uses three custom overlays for hardware compatibility:

**intel-firmware.nix**: Updates Intel GPU firmware for Meteor Lake
- Source: intel-gpu/intel-gpu-firmware repository
- Adds: mtl_guc_70.6.4.bin, mtl_huc_8.4.3_gsc.bin, mtl_gsc_102.0.0.1511.bin
- Target: `/lib/firmware/i915/` for xe driver support

**kernel.nix**: Linux 6.17 kernel configuration
- Upgraded from 6.6 for better Meteor Lake support
- SR-IOV compatibility improvements
- PXP (Protected Xe Path) support available but disabled

**nvidia-container-toolkit.nix**: NVIDIA container runtime fixes
- Ensures nvidia-container-cli binary accessibility
- Post-install verification and warning system
- Resolves container toolkit integration issues

### Flexible Graphics System
The new graphics system uses a unified module with configurable options:
```nix
gremlin.graphics = {
  intel.enable = true;           # Enable Intel Arc graphics
  intel.sriov = true;            # Enable SR-IOV (requires intel.enable)
  nvidia.enable = false;         # Enable NVIDIA graphics
};
```

### Kubernetes Configuration
- **Cluster Token**: Static token "532a3cf6ea" for node authentication
- **Leader Node**: gremlin-1 initializes cluster with clusterInit = true
- **Server Nodes**: gremlin-2/3/4 join cluster at https://10.1.1.12:6443
- **Container Runtime**: Containerd with unix socket endpoint
- **Default Runtime**: Automatically selects nvidia or runc based on graphics config
- **GPU Runtimes**:
  - `nvidia`: NVIDIA Container Runtime with CDI support
  - `intel-gpu`: Custom runtime with video group access (GID 500)
  - `runc`: Standard container runtime
- **CNI Configuration**: Flannel + full plugin suite (bridge, host-local, vlan)
- **Device Permissions**: Intel GPU devices (renderD128) accessible to video group

### Kernel Configuration
- **Linux 6.17**: Latest stable kernel for Meteor Lake support
- **xe Driver**: Intel's xe driver with SR-IOV patches
- **SR-IOV Parameters**: Conditional based on graphics configuration
- **VFIO Support**: GPU passthrough capabilities
- **Huge Pages**: 1GB and 2MB huge page support
- **PXP Support**: Protected Xe Path disabled (not needed for current SR-IOV)

### SR-IOV Implementation
- **xe-sriov Module**: Based on bbaa-bbaa/i915-sriov-dkms
- **Modprobe Override**: Forces patched xe module over stock kernel module
- **Automatic VF Creation**: 7 virtual functions per Intel Arc iGPU
- **VFIO Binding**: Automatic binding of VFs for passthrough
- **Service Management**: Systemd service for VF configuration

### Graphics Stack
- **Intel Arc Support**: Full hardware acceleration with xe driver
- **NVIDIA Integration**: RTX 4070 Ti SUPER with open drivers
- **Hybrid Configuration**: Both Intel and NVIDIA on same system
- **Container Support**: GPU access for containers and VMs

### Container Runtime
- **Containerd**: Primary container runtime with K3s integration
- **GPU Runtimes**: Conditional NVIDIA and Intel GPU runtime support
- **CNI Plugins**: Full networking plugin suite (flannel, bridge, host-local, vlan)
- **CDI Support**: Container Device Interface for NVIDIA GPU resources
- **Intel GPU Runtime**: Custom runtime with video group access for Intel Arc
- **Runtime Selection**: Automatic default runtime based on graphics configuration
- **Device Management**: Automatic Intel GPU device permissions and udev rules
- **Service Dependencies**: Proper startup ordering for GPU services

### Distributed Build System
- **Cross-Node Building**: Each node can build on other cluster nodes
- **Self-Exclusion Logic**: Prevents nodes from building on themselves
- **Load Management**: 50% CPU utilization limit per remote build
- **SSH-Based**: Secure remote build execution

### Monitoring Stack
- **Node Exporter**: System metrics collection
- **Intel GPU Top**: GPU utilization monitoring
- **Telegraf**: Metrics aggregation and forwarding
- **UPS Monitoring**: Power status and battery metrics

## Setup and Deployment

### Initial Setup
1. **Hardware Configuration**: Copy hardware-configuration.nix from each system
2. **Network Setup**: Configure bonded interfaces and IP addresses
3. **Graphics Configuration**: Set Intel/NVIDIA options per node in flake.nix
4. **Certificate Installation**: Place CA certificates in `.config/Certificates/`
5. **UPS Configuration**: Set up password files for UPS monitoring

### Deployment Process
1. **Update Dependencies**: `nix flake update`
2. **Build Configuration**: `sudo nixos-rebuild build --flake .#<hostname>`
3. **Deploy Changes**: `sudo nixos-rebuild switch --flake .#<hostname>`
4. **Verify Services**: Check Kubernetes, monitoring, and UPS status
5. **Verify SR-IOV**: Check VF creation and GPU passthrough

### Cluster Operations
1. **Initialize Cluster**: Deploy gremlin-1 first (cluster leader)
2. **Join Nodes**: Deploy remaining nodes to join cluster
3. **Verify Connectivity**: Check K3s cluster status and GPU availability
4. **Monitor Health**: Verify monitoring and UPS integration

## Troubleshooting

### SR-IOV Issues
```bash
# Check VF creation
cat /sys/devices/pci0000:00/0000:00:02.0/sriov_numvfs

# Verify VF devices
lspci | grep "00:02"

# Check SR-IOV service
systemctl status i915-sriov-setup
journalctl -u i915-sriov-setup

# Verify xe driver with SR-IOV support
modinfo xe | grep -E "(version|description)"
dmesg | grep "PF: Enabled"
```

### Graphics Driver Issues
```bash
# Check which xe module is loaded
lsmod | grep xe
modinfo xe

# Check for driver conflicts
dmesg | grep -E "(xe|i915).*error"

# Verify graphics configuration
lspci | grep -E "(VGA|3D)"
```

### Kubernetes Issues
```bash
# Check cluster status
kubectl get nodes

# Verify GPU resources
kubectl describe nodes | grep -A5 -B5 gpu

# Monitor K3s logs
journalctl -u k3s
```

### Network Issues
```bash
# Check bond status
cat /proc/net/bonding/bond0

# Verify connectivity
systemctl status systemd-networkd
ping <other-nodes>
```

## Security Considerations

- **Firewall**: Disabled for cluster communication (isolated network)
- **SSH Access**: Root login enabled for system management
- **Certificate Management**: Custom CA for internal services
- **UPS Security**: Password-protected UPS monitoring
- **GPU Security**: VFIO isolation for GPU passthrough

## Hardware Notes

### Hardware Revisions
- **Rev1 Hardware**: gremlin-1, gremlin-3 (original design)
- **Rev2 Hardware**: gremlin-2 (improved design)
- **Compatibility**: Both revisions support same software configuration

### Graphics Hardware
- **Intel Arc**: Meteor Lake integrated graphics (iGPU) with xe driver
- **NVIDIA RTX 4070 Ti SUPER**: High-performance discrete GPU
- **SR-IOV Support**: 7 virtual functions per Intel Arc iGPU

## Future Enhancements

- **gremlin-4 Deployment**: Complete 4-node cluster
- **NVIDIA Expansion**: Add NVIDIA GPU to gremlin-2
- **Storage Integration**: Distributed storage with GPU acceleration
- **Workload Optimization**: GPU-accelerated container workloads
- **Monitoring Enhancement**: GPU-specific metrics and alerting
