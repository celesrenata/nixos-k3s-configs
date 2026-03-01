# ClusterJellyfin Quick Reference

## Installation Commands

```bash
# Add Helm repository
helm repo add clusterjellyfin https://celesrenata.github.io/clusterjellyfin
helm repo update

# Install
helm install jellyfin clusterjellyfin/clusterjellyfin \
  --namespace jellyfin-system \
  --create-namespace \
  -f values.yaml

# Upgrade
helm upgrade jellyfin clusterjellyfin/clusterjellyfin \
  --namespace jellyfin-system \
  -f values.yaml

# Uninstall
helm uninstall jellyfin --namespace jellyfin-system
```

## Essential Configuration

### PostgreSQL Secret
```bash
kubectl create secret generic jellyfin-postgresql-external \
  --from-literal=host="postgres.example.com" \
  --from-literal=port="5432" \
  --from-literal=database="clusterjellyfin" \
  --from-literal=username="jellyfin" \
  --from-literal=password="your-password" \
  -n jellyfin-system
```

### Minimal values.yaml
```yaml
postgresql:
  enabled: false
  external:
    existingSecret: "jellyfin-postgresql-external"

jellyfin:
  storage:
    config:
      storageClass: "longhorn"
    cache:
      storageClass: "longhorn"
    media:
      storageClass: "nfs-client"

workers:
  replicas: 3
  privileged: true
```

## Diagnostic Commands

### Status Check
```bash
kubectl get pods -n jellyfin-system
kubectl get pvc -n jellyfin-system
kubectl get svc,ingress -n jellyfin-system
```

### Logs
```bash
# Main pod
kubectl logs -n jellyfin-system -l component=main --tail=100

# Workers
kubectl logs -n jellyfin-system jellyfin-clusterjellyfin-workers-0 --tail=100

# Follow logs
kubectl logs -n jellyfin-system -l component=main -f
```

### Testing
```bash
# Test distributed transcoding
kubectl exec -n jellyfin-system deployment/jellyfin-clusterjellyfin-main -- \
  /shared/rffmpeg -f lavfi -i testsrc=duration=1:size=320x240:rate=1 -c:v libx264 -f null -

# Test SSH connectivity
kubectl exec -n jellyfin-system deployment/jellyfin-clusterjellyfin-main -- \
  ssh jellyfin@jellyfin-clusterjellyfin-workers "echo test"

# Check GPU access
kubectl exec -n jellyfin-system jellyfin-clusterjellyfin-workers-0 -- ls -la /dev/dri/
```

## Common Configurations

### Intel Arc Graphics
```yaml
workers:
  privileged: true
  gpu:
    enabled: true
    resource: "gpu.intel.com/i915"
    limit: 1
```

### NVIDIA GPU
```yaml
workers:
  privileged: true
  gpu:
    enabled: true
    resource: "nvidia.com/gpu"
    limit: 1
```

### NFS Storage
```yaml
jellyfin:
  storage:
    media:
      storageClass: ""
      nfs:
        server: "192.168.1.100"
        path: "/mnt/media"
```

### Ingress with TLS
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

## Scaling Operations

### Scale Workers
```bash
# Via kubectl
kubectl scale statefulset jellyfin-clusterjellyfin-workers --replicas=5 -n jellyfin-system

# Via Helm
helm upgrade jellyfin clusterjellyfin/clusterjellyfin \
  --set workers.replicas=5 \
  --namespace jellyfin-system
```

### Resource Updates
```bash
# Increase memory
helm upgrade jellyfin clusterjellyfin/clusterjellyfin \
  --set jellyfin.resources.limits.memory=8Gi \
  --namespace jellyfin-system

# Update storage size (requires PVC expansion support)
helm upgrade jellyfin clusterjellyfin/clusterjellyfin \
  --set jellyfin.storage.cache.size=100Gi \
  --namespace jellyfin-system
```

## Troubleshooting Quick Fixes

### Pod Restart Issues
```bash
# Check events
kubectl get events -n jellyfin-system --sort-by='.lastTimestamp'

# Force pod restart
kubectl delete pod -n jellyfin-system -l component=main
```

### SSH Key Issues
```bash
# Regenerate SSH keys
kubectl delete job -n jellyfin-system jellyfin-clusterjellyfin-ssh-keygen
helm upgrade jellyfin clusterjellyfin/clusterjellyfin --namespace jellyfin-system
```

### Storage Issues
```bash
# Check PVC status
kubectl describe pvc -n jellyfin-system

# Test NFS connectivity
kubectl run nfs-test --image=busybox --rm -it --restart=Never -- \
  showmount -e <nfs-server-ip>
```

## Access Methods

### Port Forward (Testing)
```bash
kubectl port-forward -n jellyfin-system svc/jellyfin-clusterjellyfin-main 8096:8096
# Access: http://localhost:8096
```

### LoadBalancer Service
```yaml
service:
  type: LoadBalancer
```

### Ingress (Production)
```yaml
ingress:
  enabled: true
  hosts:
    - host: jellyfin.yourdomain.com
```

## Monitoring

### Resource Usage
```bash
kubectl top pods -n jellyfin-system
kubectl top nodes
```

### Storage Usage
```bash
kubectl exec -n jellyfin-system deployment/jellyfin-clusterjellyfin-main -- df -h
```

### Active Transcoding
```bash
kubectl exec -n jellyfin-system deployment/jellyfin-clusterjellyfin-main -- \
  ls -la /cache/transcodes/
```

## Backup and Recovery

### Configuration Backup
```bash
kubectl exec -n jellyfin-system deployment/jellyfin-clusterjellyfin-main -- \
  tar -czf /tmp/config-backup.tar.gz -C /config .
kubectl cp jellyfin-system/<pod-name>:/tmp/config-backup.tar.gz ./config-backup.tar.gz
```

### Database Backup
```bash
kubectl exec -n jellyfin-system deployment/jellyfin-clusterjellyfin-main -- \
  pg_dump -h $JELLYFIN_POSTGRES_HOST -U $JELLYFIN_POSTGRES_USER \
  $JELLYFIN_POSTGRES_DATABASE > jellyfin-db-backup.sql
```

### Complete Reset
```bash
helm uninstall jellyfin --namespace jellyfin-system
kubectl delete pvc -n jellyfin-system --all  # WARNING: Deletes all data
kubectl delete namespace jellyfin-system
```

## Performance Optimization

### Fast Storage for Cache
```yaml
jellyfin:
  storage:
    cache:
      storageClass: "fast-ssd"  # Use fastest available storage
```

### Worker Optimization
```yaml
workers:
  replicas: 4  # Match available CPU cores
  resources:
    requests:
      cpu: 2000m
      memory: 4Gi
    limits:
      cpu: 4000m
      memory: 8Gi
```

### Node Affinity for GPU
```yaml
workers:
  nodeSelector:
    enabled: true
    nodes:
      - gpu-node-1
      - gpu-node-2
```

## Security

### Network Policies
```yaml
# Restrict pod communication
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: jellyfin-network-policy
spec:
  podSelector:
    matchLabels:
      app: clusterjellyfin
  policyTypes:
  - Ingress
  - Egress
```

### TLS Configuration
```yaml
ingress:
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  tls:
    - secretName: jellyfin-tls
      hosts:
        - jellyfin.yourdomain.com
```

## Useful Aliases

Add to your shell profile:
```bash
alias jf-pods='kubectl get pods -n jellyfin-system'
alias jf-logs='kubectl logs -n jellyfin-system -l component=main --tail=100'
alias jf-workers='kubectl logs -n jellyfin-system jellyfin-clusterjellyfin-workers-0 --tail=100'
alias jf-exec='kubectl exec -n jellyfin-system deployment/jellyfin-clusterjellyfin-main --'
alias jf-test='kubectl exec -n jellyfin-system deployment/jellyfin-clusterjellyfin-main -- /shared/rffmpeg -f lavfi -i testsrc=duration=1:size=320x240:rate=1 -c:v libx264 -f null -'
```
