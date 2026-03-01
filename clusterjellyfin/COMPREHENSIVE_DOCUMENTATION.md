# ClusterJellyfin - Comprehensive Documentation

## Overview

ClusterJellyfin is a specialized Kubernetes deployment of Jellyfin that enables distributed transcoding across multiple worker pods. It combines a custom Jellyfin build with PostgreSQL backend support and rffmpeg for remote transcoding distribution.

## Architecture

```
┌─────────────────┐    SSH/rffmpeg    ┌─────────────────┐
│   Jellyfin      │ ────────────────▶ │   Worker Pods   │
│   Main Pod      │                   │   (StatefulSet) │
│   (Web UI +     │                   │   FFmpeg +      │
│    PostgreSQL)  │                   │   HW Accel      │
└─────────────────┘                   └─────────────────┘
         │                                       │
         ▼                                       ▼
┌─────────────────┐                   ┌─────────────────┐
│   PostgreSQL    │                   │   Shared Cache  │
│   Database      │                   │   (NFS/RWX)     │
│   (External)    │                   │   /cache        │
└─────────────────┘                   └─────────────────┘
```

## Key Components

### 1. Custom Jellyfin Build
- **Base**: Official Jellyfin 10.9.11+ with PostgreSQL support
- **Enhancements**: 
  - PostgreSQL database provider implementation
  - rffmpeg integration for distributed transcoding
  - Kubernetes-optimized configuration
- **Container**: `ghcr.io/celesrenata/clusterjellyfin-main`

### 2. Transcoding Workers
- **Purpose**: Dedicated FFmpeg processing pods
- **Features**: Hardware acceleration (Intel Arc, NVIDIA, AMD)
- **Communication**: SSH-based job distribution via rffmpeg
- **Container**: `ghcr.io/celesrenata/clusterjellyfin-worker`

### 3. rffmpeg Integration
- **Function**: Distributes transcoding jobs across worker pods
- **Protocol**: SSH with automatic key management
- **Load Balancing**: Round-robin job distribution
- **Validation**: Local execution for version checks, remote for transcoding

## Installation Methods

### Method 1: Helm Repository (Recommended)

```bash
# Add repository
helm repo add clusterjellyfin https://celesrenata.github.io/clusterjellyfin
helm repo update

# Install with custom values
helm install jellyfin clusterjellyfin/clusterjellyfin \
  --namespace jellyfin-system \
  --create-namespace \
  -f values.yaml
```

### Method 2: Local Chart

```bash
# Clone repository
git clone https://github.com/celesrenata/clusterjellyfin
cd clusterjellyfin

# Install from local chart
helm install jellyfin ./charts/clusterjellyfin \
  --namespace jellyfin-system \
  --create-namespace \
  -f values.yaml
```

## Configuration Guide

### Essential Configuration

#### 1. PostgreSQL Database (Required)

**External PostgreSQL (Recommended):**
```yaml
postgresql:
  enabled: false
  external:
    host: "postgres.example.com"
    port: 5432
    database: "clusterjellyfin"
    username: "jellyfin"
    existingSecret: "jellyfin-postgresql-external"
```

**Create PostgreSQL secret:**
```bash
kubectl create secret generic jellyfin-postgresql-external \
  --from-literal=host="YOUR_POSTGRES_HOST" \
  --from-literal=port="5432" \
  --from-literal=database="clusterjellyfin" \
  --from-literal=username="jellyfin" \
  --from-literal=password="YOUR_PASSWORD" \
  -n jellyfin-system
```

#### 2. Storage Configuration

**NFS Storage (Recommended for media):**
```yaml
jellyfin:
  storage:
    config:
      size: 10Gi
      storageClass: "longhorn"
    cache:
      size: 50Gi
      storageClass: "longhorn"  # Fast storage for transcoding
      accessMode: ReadWriteMany
    media:
      size: 5Ti
      storageClass: ""
      nfs:
        server: "192.168.1.100"
        path: "/mnt/media"
```

**Dynamic Provisioning:**
```yaml
jellyfin:
  storage:
    config:
      storageClass: "longhorn"
    cache:
      storageClass: "longhorn"
    media:
      storageClass: "nfs-client"
```

#### 3. Worker Configuration

**Basic Workers:**
```yaml
workers:
  replicas: 3
  privileged: true
  resources:
    requests:
      cpu: 2000m
      memory: 4Gi
    limits:
      cpu: 4000m
      memory: 8Gi
```

**GPU-Enabled Workers:**
```yaml
workers:
  replicas: 3
  privileged: true
  nodeSelector:
    enabled: true
    nodes:
      - gpu-node-1
      - gpu-node-2
  gpu:
    enabled: true
    resource: "gpu.intel.com/i915"  # Intel Arc
    # resource: "nvidia.com/gpu"    # NVIDIA
    limit: 1
```

### Advanced Configuration

#### Network Access

**LoadBalancer Service:**
```yaml
service:
  type: LoadBalancer
  annotations:
    metallb.universe.tf/address-pool: default
```

**Ingress with TLS:**
```yaml
ingress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: jellyfin.yourdomain.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: jellyfin-tls
      hosts:
        - jellyfin.yourdomain.com
```

#### Resource Optimization

**Main Pod Resources:**
```yaml
jellyfin:
  resources:
    requests:
      cpu: 1000m
      memory: 2Gi
    limits:
      cpu: 2000m
      memory: 4Gi
```

**Worker Pod Resources:**
```yaml
workers:
  resources:
    requests:
      cpu: 2000m
      memory: 4Gi
    limits:
      cpu: 4000m
      memory: 8Gi
```

## Hardware Acceleration

### Intel Arc Graphics

**Requirements:**
- Intel Arc GPU drivers on nodes
- Intel GPU device plugin installed
- Privileged containers enabled

**Configuration:**
```yaml
workers:
  privileged: true
  gpu:
    enabled: true
    resource: "gpu.intel.com/i915"
    limit: 1
```

**Verification:**
```bash
# Check GPU availability
kubectl describe node <gpu-node> | grep gpu.intel.com/i915

# Test GPU access in worker
kubectl exec -n jellyfin-system jellyfin-clusterjellyfin-workers-0 -- \
  ls -la /dev/dri/
```

### NVIDIA GPU

**Requirements:**
- NVIDIA GPU drivers
- NVIDIA device plugin
- NVIDIA container runtime

**Configuration:**
```yaml
workers:
  privileged: true
  gpu:
    enabled: true
    resource: "nvidia.com/gpu"
    limit: 1
```

### AMD VAAPI

**Requirements:**
- AMD GPU drivers
- VAAPI support

**Configuration:**
```yaml
workers:
  privileged: true
  gpu:
    enabled: true
    resource: "amd.com/gpu"
    limit: 1
```

## Distributed Transcoding

### How It Works

1. **Job Distribution**: Jellyfin main pod uses rffmpeg to distribute transcoding jobs
2. **SSH Communication**: Automatic SSH key generation and distribution
3. **Load Balancing**: Jobs distributed across available worker pods
4. **Shared Cache**: Workers write HLS segments to shared cache volume
5. **Hardware Acceleration**: GPU resources available on worker pods

### Monitoring Transcoding

**Check active transcoding:**
```bash
# View cache directory
kubectl exec -n jellyfin-system deployment/jellyfin-clusterjellyfin-main -- \
  ls -la /cache/transcodes/

# Monitor worker activity
kubectl logs -n jellyfin-system jellyfin-clusterjellyfin-workers-0 -f

# Check SSH connectivity
kubectl exec -n jellyfin-system deployment/jellyfin-clusterjellyfin-main -- \
  ssh -o StrictHostKeyChecking=no -i /home/jellyfin/.ssh/id_rsa \
  jellyfin@jellyfin-clusterjellyfin-workers "echo 'SSH works'"
```

**Test distributed transcoding:**
```bash
kubectl exec -n jellyfin-system deployment/jellyfin-clusterjellyfin-main -- \
  /shared/rffmpeg -f lavfi -i testsrc=duration=1:size=320x240:rate=1 \
  -c:v libx264 -f null -
```

## Troubleshooting

### Common Issues

#### 1. Pod Restarts with Exit Code 139
**Cause**: Segfault during initial library scan (known issue)
**Solution**: 
- Expected behavior during first startup
- Pod should stabilize after 2-3 restarts
- Increase memory limits if persistent

#### 2. SSH Connection Errors
**Symptoms**: "Failed to add host to known hosts"
**Cause**: Load balancer distributing SSH connections
**Solution**: This is normal behavior - SSH still works

#### 3. Transcoding Jobs Not Distributed
**Check**:
```bash
# Verify worker pods are running
kubectl get pods -n jellyfin-system

# Check SSH keys exist
kubectl get secret -n jellyfin-system | grep ssh

# Test SSH connectivity
kubectl exec -n jellyfin-system deployment/jellyfin-clusterjellyfin-main -- \
  ssh jellyfin@jellyfin-clusterjellyfin-workers "echo test"
```

#### 4. Storage Issues
**NFS Mount Failures:**
```bash
# Check NFS server accessibility
kubectl exec -n jellyfin-system deployment/jellyfin-clusterjellyfin-main -- \
  showmount -e <nfs-server-ip>

# Verify PVC status
kubectl get pvc -n jellyfin-system
```

**Storage Class Issues:**
```bash
# List available storage classes
kubectl get storageclass

# Check PV binding
kubectl get pv | grep jellyfin
```

#### 5. PostgreSQL Connection Issues
**Check connection:**
```bash
# View PostgreSQL logs
kubectl logs -n jellyfin-system -l component=main | grep -i postgres

# Test database connection
kubectl exec -n jellyfin-system deployment/jellyfin-clusterjellyfin-main -- \
  pg_isready -h $JELLYFIN_POSTGRES_HOST -p $JELLYFIN_POSTGRES_PORT
```

### Diagnostic Commands

**Pod Status:**
```bash
kubectl get pods -n jellyfin-system -o wide
kubectl describe pod -n jellyfin-system <pod-name>
```

**Logs:**
```bash
# Main pod logs
kubectl logs -n jellyfin-system -l component=main --tail=100

# Worker logs
kubectl logs -n jellyfin-system jellyfin-clusterjellyfin-workers-0 --tail=100

# Init container logs
kubectl logs -n jellyfin-system -l component=main -c install-rffmpeg
```

**Storage:**
```bash
kubectl get pv,pvc -n jellyfin-system
kubectl exec -n jellyfin-system deployment/jellyfin-clusterjellyfin-main -- df -h
```

**Network:**
```bash
kubectl get svc,ingress -n jellyfin-system
kubectl port-forward -n jellyfin-system svc/jellyfin-clusterjellyfin-main 8096:8096
```

## Maintenance

### Upgrading

```bash
# Update Helm repository
helm repo update

# Upgrade installation
helm upgrade jellyfin clusterjellyfin/clusterjellyfin \
  --namespace jellyfin-system \
  -f values.yaml
```

### Backup

**Configuration Backup:**
```bash
# Backup Jellyfin config
kubectl exec -n jellyfin-system deployment/jellyfin-clusterjellyfin-main -- \
  tar -czf /tmp/jellyfin-config.tar.gz -C /config .

kubectl cp jellyfin-system/<pod-name>:/tmp/jellyfin-config.tar.gz ./jellyfin-config.tar.gz
```

**PostgreSQL Backup:**
```bash
# Database backup
kubectl exec -n jellyfin-system deployment/jellyfin-clusterjellyfin-main -- \
  pg_dump -h $JELLYFIN_POSTGRES_HOST -U $JELLYFIN_POSTGRES_USER \
  $JELLYFIN_POSTGRES_DATABASE > jellyfin-db-backup.sql
```

### Scaling Workers

```bash
# Scale workers dynamically
kubectl scale statefulset jellyfin-clusterjellyfin-workers \
  --replicas=5 -n jellyfin-system

# Or update Helm values
helm upgrade jellyfin clusterjellyfin/clusterjellyfin \
  --set workers.replicas=5 \
  --namespace jellyfin-system
```

## Performance Optimization

### Storage Performance
- Use fast SSD storage for cache volume
- NFS for media (large capacity)
- Local storage for config (small, fast)

### Worker Optimization
- Match worker count to available CPU cores
- Enable GPU acceleration when available
- Use node affinity for GPU nodes

### Network Optimization
- Use LoadBalancer or Ingress for external access
- Enable TLS termination at ingress level
- Configure appropriate resource limits

## Security Considerations

### Network Security
- Use network policies to restrict pod communication
- Enable TLS for external access
- Secure PostgreSQL connection with SSL

### Container Security
- Workers run in privileged mode for GPU access
- SSH keys automatically generated and managed
- Non-root user context where possible

### Data Security
- Encrypt storage volumes
- Secure PostgreSQL credentials in secrets
- Regular backup of configuration and database

## Complete Example Configuration

See the next section for a complete production-ready configuration example.
