# NetBootXYZ with Multus Secondary CNI Integration

This directory contains the NetBootXYZ deployment configured to use **Multus secondary CNI** for multi-network capabilities.

## ✅ Configuration Overview

NetBootXYZ is configured to use:
- **Primary network (eth0)**: Flannel - for Kubernetes cluster communication
- **Secondary network (net1)**: VLAN 100 - for DHCP/TFTP services with static IP

## 🌐 Network Configuration

### Static IP Assignment
NetBootXYZ is configured with a **static IP address** on VLAN 100:
- **IP Address**: `192.168.42.16/24`
- **Network**: VLAN 100 (vlan100-net)
- **Gateway**: `192.168.42.1`

### Multus Annotation
The deployment uses the following annotation to request the secondary network:
```yaml
annotations:
  k8s.v1.cni.cncf.io/networks: '[{"name": "vlan100-net", "ips": ["192.168.42.16/24"]}]'
```

## 📁 Key Files

### `netbootxyz-deployment.yaml`
Main deployment file with Multus configuration:
- **Primary CNI**: Flannel (automatic)
- **Secondary CNI**: Multus with VLAN 100 static IP
- **Privileged container**: Required for DHCP/TFTP raw socket access

### Other Files
- `netbootxyz-service.yaml` - Kubernetes service definition
- `netbootxyz-pvc.yaml` - Persistent volume claims for config and assets
- `netbootxyz-pv.yaml` - Persistent volumes
- `netbootxyz-ingress-https.yaml` - HTTPS ingress configuration

## 🚀 Deployment

### Prerequisites
1. **Multus CNI** must be configured as secondary CNI (see ../multus/README-NixOS-Setup.md)
2. **VLAN 100 NetworkAttachmentDefinition** must exist (vlan100-net)
3. **RBAC permissions** must be configured for cross-namespace pod access

### Deploy NetBootXYZ
```bash
# Deploy all components
./runmefirst.sh

# Or deploy manually
kubectl apply -f netbootxyz-pv.yaml
kubectl apply -f netbootxyz-pvc.yaml
kubectl apply -f netbootxyz-deployment.yaml
kubectl apply -f netbootxyz-service.yaml
kubectl apply -f netbootxyz-ingress-https.yaml
```

### Verify Deployment
```bash
# Check pod status
kubectl get pods -l io.kompose.service=netbootxyz

# Check network interfaces
kubectl exec deployment/netbootxyz -- ip addr show

# Expected output:
# 1: lo: <LOOPBACK,UP,LOWER_UP> ...
# 2: eth0@if123: <BROADCAST,MULTICAST,UP,LOWER_UP> ... (Flannel)
#    inet 10.42.x.x/24 ...
# 3: net1@if456: <BROADCAST,MULTICAST,UP,LOWER_UP> ... (VLAN 100)
#    inet 192.168.42.16/24 ...
```

## 🔧 How It Works

### Normal Pod Behavior (Without Multus Annotation)
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: normal-pod
spec:
  containers:
  - name: app
    image: nginx
# Result: Only eth0 (Flannel) interface
```

### NetBootXYZ Multi-Network Behavior (With Multus Annotation)
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: netbootxyz
  annotations:
    k8s.v1.cni.cncf.io/networks: '[{"name": "vlan100-net", "ips": ["192.168.42.16/24"]}]'
spec:
  containers:
  - name: netbootxyz
    image: linuxserver/netbootxyz
# Result: eth0 (Flannel) + net1 (VLAN 100 with static IP)
```

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    NetBootXYZ Pod                           │
├─────────────────────────────────────────────────────────────┤
│ eth0: 10.42.x.x/24    │ net1: 192.168.42.16/24             │
│ (Flannel - K8s)       │ (VLAN 100 - DHCP/TFTP)             │
│ ↓                     │ ↓                                   │
│ Kubernetes Services   │ Physical Network VLAN 100          │
│ Ingress, DNS, etc.    │ PXE Boot Clients                    │
└─────────────────────────────────────────────────────────────┘
```

## 🎯 Benefits

### ✅ **Network Separation**
- **Kubernetes traffic** uses Flannel network (eth0)
- **DHCP/TFTP traffic** uses VLAN 100 network (net1)
- **No interference** between management and boot services

### ✅ **Static IP for Services**
- **Predictable IP**: `192.168.42.16` for DHCP/TFTP
- **Easy configuration**: Clients can point to known IP
- **Network planning**: IP is reserved and documented

### ✅ **Secondary CNI Benefits**
- **Normal pods unaffected**: Only NetBootXYZ gets additional network
- **Selective networking**: Multi-network only where needed
- **Performance**: No overhead for pods that don't need it

## 🔍 Troubleshooting

### Pod Stuck in ContainerCreating
```bash
# Check if Multus RBAC is configured
kubectl get clusterrolebinding multus

# Check if NetworkAttachmentDefinition exists
kubectl get network-attachment-definitions vlan100-net

# Check pod events
kubectl describe pod -l io.kompose.service=netbootxyz
```

### Network Interface Missing
```bash
# Verify CNI configuration
ssh root@node "ls -la /var/lib/rancher/k3s/agent/etc/cni/net.d/"
# Should show: 10-flannel.conflist, 99-multus.conflist

# Check Multus logs
kubectl logs -n kube-system -l app=multus
```

### VLAN Connectivity Issues
```bash
# Test VLAN gateway from pod
kubectl exec deployment/netbootxyz -- ping 192.168.42.1

# Check VLAN interface configuration
kubectl exec deployment/netbootxyz -- ip route show
```

## 📚 Related Documentation

- **Multus Setup**: `../multus/README-NixOS-Setup.md`
- **NetworkAttachmentDefinition**: `../multus/simple-vlan-nad.yaml`
- **NixOS Configuration**: See multus directory for complete setup

This configuration provides NetBootXYZ with the networking capabilities it needs while maintaining clean separation between Kubernetes management traffic and PXE boot services! 🚀
