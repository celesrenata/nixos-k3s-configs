# ClusterJellyfin Installation Guide

## Prerequisites

- Kubernetes cluster (tested on K3s)
- Helm 3.x
- Storage solution (NFS server or dynamic provisioning)
- External PostgreSQL database (recommended)
- Ingress controller (Traefik, NGINX, etc.)

## Quick Installation

### 1. Add Helm Repository

```bash
helm repo add clusterjellyfin https://celesrenata.github.io/clusterjellyfin
helm repo update
```

### 2. Create PostgreSQL Secret

Create a secret with your PostgreSQL connection details:

```bash
kubectl create secret generic jellyfin-postgresql-external \
  --from-literal=host="YOUR_POSTGRES_HOST" \
  --from-literal=port="5432" \
  --from-literal=database="clusterjellyfin" \
  --from-literal=username="jellyfin" \
  --from-literal=password="YOUR_PASSWORD" \
  -n jellyfin-system
```

### 3. Create Values File

Create `values.yaml` with your configuration:

```yaml
# Basic configuration
jellyfin:
  publishedServerUrl: "https://jellyfin.yourdomain.com"
  
  storage:
    config:
      size: 10Gi
      storageClass: "longhorn"  # or your storage class
    cache:
      size: 50Gi
      storageClass: "longhorn"  # fast storage recommended
    media:
      size: 1Ti
      storageClass: ""  # or use NFS
      nfs:
        server: "192.168.1.100"
        path: "/mnt/media"

# External PostgreSQL
postgresql:
  enabled: false
  external:
    host: "YOUR_POSTGRES_HOST"
    port: 5432
    database: "clusterjellyfin"
    username: "jellyfin"
    existingSecret: "jellyfin-postgresql-external"

# Worker configuration
workers:
  replicas: 3
  privileged: true
  nodeSelector:
    enabled: true
    nodes:
      - worker-node-1
      - worker-node-2

# Ingress
ingress:
  enabled: true
  className: "nginx"  # or "traefik"
  hosts:
    - host: jellyfin.yourdomain.com
      paths:
        - path: /
          pathType: Prefix
```

### 4. Install ClusterJellyfin

```bash
helm install jellyfin clusterjellyfin/clusterjellyfin \
  --namespace jellyfin-system \
  --create-namespace \
  -f values.yaml
```

## Configuration Options

### Storage Configuration

#### NFS Storage
```yaml
jellyfin:
  storage:
    media:
      storageClass: ""
      nfs:
        server: "192.168.1.100"
        path: "/mnt/media"
```

#### Dynamic Provisioning
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

### GPU Support

#### Intel Arc Graphics
```yaml
workers:
  privileged: true
  gpu:
    enabled: true
    resource: "gpu.intel.com/i915"
    limit: 1
```

#### NVIDIA GPU
```yaml
workers:
  privileged: true
  gpu:
    enabled: true
    resource: "nvidia.com/gpu"
    limit: 1
```

### Resource Limits

#### Main Pod
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

#### Worker Pods
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

## Verification

### Check Pod Status
```bash
kubectl get pods -n jellyfin-system
```

Expected output:
```
NAME                                             READY   STATUS    RESTARTS   AGE
jellyfin-clusterjellyfin-main-xxx                1/1     Running   0          5m
jellyfin-clusterjellyfin-workers-0               1/1     Running   0          5m
jellyfin-clusterjellyfin-workers-1               1/1     Running   0          5m
jellyfin-clusterjellyfin-workers-2               1/1     Running   0          5m
```

### Test Distributed Transcoding
```bash
kubectl exec -n jellyfin-system deployment/jellyfin-clusterjellyfin-main -- \
  /shared/rffmpeg -f lavfi -i testsrc=duration=1:size=320x240:rate=1 -c:v libx264 -f null -
```

### Check PostgreSQL Connection
```bash
kubectl logs -n jellyfin-system -l component=main | grep -i postgres
```

Should show: `PostgreSQL connection string: Host=...`

## Troubleshooting

### Common Issues

#### Pod Restarts with Exit Code 139
- This is expected during initial startup (segfault during library scan)
- Pod should stabilize after 2-3 restarts
- Increase memory limits if persistent

#### SSH Connection Errors
- "Failed to add host to known hosts" is normal (load balancer)
- Check worker pods are running
- Verify SSH keys are generated

#### Storage Issues
- Ensure NFS server is accessible from all nodes
- Check storage class exists: `kubectl get storageclass`
- Verify PVCs are bound: `kubectl get pvc -n jellyfin-system`

### Logs
```bash
# Main pod logs
kubectl logs -n jellyfin-system -l component=main

# Worker logs
kubectl logs -n jellyfin-system jellyfin-clusterjellyfin-workers-0

# Init container logs
kubectl logs -n jellyfin-system -l component=main -c install-rffmpeg
```

## Upgrading

```bash
helm repo update
helm upgrade jellyfin clusterjellyfin/clusterjellyfin \
  --namespace jellyfin-system \
  -f values.yaml
```

## Uninstalling

```bash
helm uninstall jellyfin --namespace jellyfin-system
kubectl delete namespace jellyfin-system
```

## Architecture

```
┌─────────────────┐    SSH/rffmpeg    ┌─────────────────┐
│   Jellyfin      │ ────────────────▶ │   Worker Pods   │
│   Main Pod      │                   │                 │
│   (Web UI)      │                   │   FFmpeg +      │
│                 │                   │   HW Accel      │
└─────────────────┘                   └─────────────────┘
         │                                       │
         ▼                                       ▼
┌─────────────────┐                   ┌─────────────────┐
│   PostgreSQL    │                   │   Shared Cache  │
│   Database      │                   │   (NFS/RWX)     │
└─────────────────┘                   └─────────────────┘
```

## Features

- ✅ Distributed transcoding across multiple worker pods
- ✅ PostgreSQL backend for better performance
- ✅ Hardware acceleration support (Intel Arc, NVIDIA, AMD)
- ✅ Auto-scaling worker pods
- ✅ Load balancing across workers
- ✅ Persistent storage for config, cache, and media
- ✅ Ingress support with TLS
- ✅ Kubernetes-native configuration
