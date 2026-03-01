# ClusterJellyfin Troubleshooting Guide

## Quick Diagnostic Commands

### Check Overall Status
```bash
# Pod status
kubectl get pods -n jellyfin-system

# Services and ingress
kubectl get svc,ingress -n jellyfin-system

# Storage
kubectl get pv,pvc -n jellyfin-system

# Recent events
kubectl get events -n jellyfin-system --sort-by='.lastTimestamp'
```

### View Logs
```bash
# Main pod logs
kubectl logs -n jellyfin-system -l component=main --tail=100

# Worker logs
kubectl logs -n jellyfin-system jellyfin-clusterjellyfin-workers-0 --tail=100

# Init container logs
kubectl logs -n jellyfin-system -l component=main -c install-rffmpeg
```

## Common Issues and Solutions

### 1. Pod Crashes with Exit Code 139

**Symptoms:**
- Main pod restarts repeatedly
- Exit code 139 in pod status
- Segmentation fault in logs

**Cause:**
- Known issue during initial library scan
- Memory pressure during startup

**Solution:**
```bash
# This is expected behavior - pod should stabilize after 2-3 restarts
# If persistent, increase memory limits:

helm upgrade jellyfin clusterjellyfin/clusterjellyfin \
  --set jellyfin.resources.limits.memory=8Gi \
  --namespace jellyfin-system
```

**Prevention:**
- Start with higher memory limits for initial setup
- Reduce memory after stable operation

### 2. SSH Connection Issues

**Symptoms:**
- "Failed to add host to known hosts" errors
- Transcoding jobs not distributed
- SSH connection refused

**Diagnosis:**
```bash
# Check worker pods are running
kubectl get pods -n jellyfin-system | grep workers

# Verify SSH keys exist
kubectl get secret -n jellyfin-system | grep ssh

# Test SSH connectivity
kubectl exec -n jellyfin-system deployment/jellyfin-clusterjellyfin-main -- \
  ssh -o StrictHostKeyChecking=no -i /home/jellyfin/.ssh/id_rsa \
  jellyfin@jellyfin-clusterjellyfin-workers "echo 'SSH test successful'"
```

**Solutions:**

**Missing SSH Keys:**
```bash
# Delete and recreate SSH job
kubectl delete job -n jellyfin-system jellyfin-clusterjellyfin-ssh-keygen
helm upgrade jellyfin clusterjellyfin/clusterjellyfin --namespace jellyfin-system
```

**Worker Pods Not Ready:**
```bash
# Check worker pod status
kubectl describe pod -n jellyfin-system jellyfin-clusterjellyfin-workers-0

# Check worker logs
kubectl logs -n jellyfin-system jellyfin-clusterjellyfin-workers-0
```

**Load Balancer Issues:**
- "Failed to add host to known hosts" is normal with load balancers
- SSH connections still work despite the warning

### 3. Storage Mount Failures

**Symptoms:**
- Pods stuck in Pending state
- "Volume mount failed" errors
- PVCs in Pending state

**Diagnosis:**
```bash
# Check PVC status
kubectl get pvc -n jellyfin-system

# Check PV availability
kubectl get pv | grep jellyfin

# Check storage classes
kubectl get storageclass

# Describe problematic PVC
kubectl describe pvc -n jellyfin-system <pvc-name>
```

**Solutions:**

**NFS Mount Issues:**
```bash
# Test NFS server accessibility
kubectl run nfs-test --image=busybox --rm -it --restart=Never -- \
  sh -c "showmount -e <nfs-server-ip>"

# Check NFS server is running
ping <nfs-server-ip>
```

**Storage Class Issues:**
```bash
# List available storage classes
kubectl get storageclass

# Check if default storage class exists
kubectl get storageclass | grep default

# Set default storage class if needed
kubectl patch storageclass <storage-class-name> \
  -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

**Insufficient Storage:**
```bash
# Check node storage capacity
kubectl describe nodes | grep -A 5 "Allocated resources"

# Reduce PVC sizes if needed
helm upgrade jellyfin clusterjellyfin/clusterjellyfin \
  --set jellyfin.storage.cache.size=25Gi \
  --namespace jellyfin-system
```

### 4. PostgreSQL Connection Issues

**Symptoms:**
- Main pod fails to start
- Database connection errors in logs
- "Connection refused" errors

**Diagnosis:**
```bash
# Check PostgreSQL logs
kubectl logs -n jellyfin-system -l component=main | grep -i postgres

# Verify secret exists
kubectl get secret -n jellyfin-system jellyfin-postgresql-external

# Test database connectivity
kubectl exec -n jellyfin-system deployment/jellyfin-clusterjellyfin-main -- \
  pg_isready -h $JELLYFIN_POSTGRES_HOST -p $JELLYFIN_POSTGRES_PORT
```

**Solutions:**

**Missing Secret:**
```bash
kubectl create secret generic jellyfin-postgresql-external \
  --from-literal=host="YOUR_POSTGRES_HOST" \
  --from-literal=port="5432" \
  --from-literal=database="clusterjellyfin" \
  --from-literal=username="jellyfin" \
  --from-literal=password="YOUR_PASSWORD" \
  -n jellyfin-system
```

**Database Doesn't Exist:**
```bash
# Connect to PostgreSQL and create database
psql -h <postgres-host> -U postgres
CREATE DATABASE clusterjellyfin;
CREATE USER jellyfin WITH PASSWORD 'your-password';
GRANT ALL PRIVILEGES ON DATABASE clusterjellyfin TO jellyfin;
```

**Network Connectivity:**
```bash
# Test from within cluster
kubectl run postgres-test --image=postgres:15 --rm -it --restart=Never -- \
  psql -h <postgres-host> -U jellyfin -d clusterjellyfin
```

### 5. GPU Not Detected

**Symptoms:**
- Hardware acceleration not working
- GPU resources not available
- Transcoding falls back to CPU

**Diagnosis:**
```bash
# Check GPU resources on nodes
kubectl describe node <gpu-node> | grep -E "gpu|Capacity|Allocatable"

# Check GPU device plugin
kubectl get pods -n kube-system | grep gpu

# Test GPU access in worker
kubectl exec -n jellyfin-system jellyfin-clusterjellyfin-workers-0 -- \
  ls -la /dev/dri/
```

**Solutions:**

**Intel Arc Graphics:**
```bash
# Install Intel GPU device plugin
kubectl apply -f https://raw.githubusercontent.com/intel/intel-device-plugins-for-kubernetes/main/deployments/gpu_plugin/base/intel-gpu-plugin.yaml

# Verify plugin is running
kubectl get pods -n kube-system | grep intel-gpu-plugin
```

**NVIDIA GPU:**
```bash
# Install NVIDIA device plugin
kubectl create -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/v0.14.0/nvidia-device-plugin.yml

# Verify plugin is running
kubectl get pods -n kube-system | grep nvidia-device-plugin
```

**Node Labels:**
```bash
# Check node has GPU labels
kubectl get nodes --show-labels | grep gpu

# Add GPU label if missing
kubectl label node <node-name> accelerator=gpu
```

### 6. Transcoding Not Working

**Symptoms:**
- Videos won't play or buffer indefinitely
- No transcoding activity in logs
- Cache directory empty

**Diagnosis:**
```bash
# Check cache directory
kubectl exec -n jellyfin-system deployment/jellyfin-clusterjellyfin-main -- \
  ls -la /cache/transcodes/

# Test rffmpeg directly
kubectl exec -n jellyfin-system deployment/jellyfin-clusterjellyfin-main -- \
  /shared/rffmpeg -f lavfi -i testsrc=duration=1:size=320x240:rate=1 -c:v libx264 -f null -

# Check FFmpeg on workers
kubectl exec -n jellyfin-system jellyfin-clusterjellyfin-workers-0 -- \
  ffmpeg -version
```

**Solutions:**

**rffmpeg Not Installed:**
```bash
# Check rffmpeg exists
kubectl exec -n jellyfin-system deployment/jellyfin-clusterjellyfin-main -- \
  ls -la /shared/rffmpeg

# Reinstall if missing
kubectl delete pod -n jellyfin-system -l component=main
```

**Cache Volume Issues:**
```bash
# Check cache volume is mounted
kubectl exec -n jellyfin-system deployment/jellyfin-clusterjellyfin-main -- \
  df -h | grep cache

# Verify workers can write to cache
kubectl exec -n jellyfin-system jellyfin-clusterjellyfin-workers-0 -- \
  touch /cache/test-file && ls -la /cache/test-file
```

**FFmpeg Configuration:**
- Check Jellyfin transcoding settings
- Ensure FFmpeg path is set to `/shared/rffmpeg`
- Verify hardware acceleration settings match GPU type

### 7. Ingress/Network Issues

**Symptoms:**
- Can't access Jellyfin web interface
- SSL certificate errors
- Timeout errors

**Diagnosis:**
```bash
# Check ingress status
kubectl get ingress -n jellyfin-system

# Check ingress controller
kubectl get pods -n ingress-nginx  # or your ingress namespace

# Test service directly
kubectl port-forward -n jellyfin-system svc/jellyfin-clusterjellyfin-main 8096:8096
```

**Solutions:**

**Ingress Controller Issues:**
```bash
# Install NGINX ingress controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
```

**Certificate Issues:**
```bash
# Check cert-manager
kubectl get pods -n cert-manager

# Check certificate status
kubectl get certificate -n jellyfin-system

# Force certificate renewal
kubectl delete certificate -n jellyfin-system jellyfin-tls
```

**DNS Issues:**
```bash
# Test DNS resolution
nslookup jellyfin.yourdomain.com

# Check ingress external IP
kubectl get ingress -n jellyfin-system -o wide
```

## Performance Issues

### High CPU Usage

**Diagnosis:**
```bash
# Check resource usage
kubectl top pods -n jellyfin-system

# Check transcoding activity
kubectl exec -n jellyfin-system deployment/jellyfin-clusterjellyfin-main -- \
  ls -la /cache/transcodes/
```

**Solutions:**
- Increase worker replicas
- Enable hardware acceleration
- Optimize transcoding settings in Jellyfin

### High Memory Usage

**Diagnosis:**
```bash
# Check memory usage
kubectl top pods -n jellyfin-system

# Check for memory leaks
kubectl logs -n jellyfin-system -l component=main | grep -i "memory\|oom"
```

**Solutions:**
- Increase memory limits
- Restart pods periodically
- Optimize library scan settings

### Slow Transcoding

**Diagnosis:**
```bash
# Check worker distribution
kubectl logs -n jellyfin-system -l component=main | grep rffmpeg

# Check GPU utilization
kubectl exec -n jellyfin-system jellyfin-clusterjellyfin-workers-0 -- \
  intel_gpu_top  # For Intel GPUs
```

**Solutions:**
- Enable hardware acceleration
- Increase worker count
- Use faster storage for cache

## Recovery Procedures

### Complete Reset

```bash
# Uninstall ClusterJellyfin
helm uninstall jellyfin --namespace jellyfin-system

# Delete persistent data (WARNING: This deletes all data)
kubectl delete pvc -n jellyfin-system --all

# Delete namespace
kubectl delete namespace jellyfin-system

# Reinstall
kubectl create namespace jellyfin-system
helm install jellyfin clusterjellyfin/clusterjellyfin \
  --namespace jellyfin-system \
  -f values.yaml
```

### Configuration Reset

```bash
# Delete only config PVC (keeps media and cache)
kubectl delete pvc -n jellyfin-system jellyfin-clusterjellyfin-config

# Restart main pod
kubectl delete pod -n jellyfin-system -l component=main
```

### Worker Reset

```bash
# Delete all workers
kubectl delete statefulset -n jellyfin-system jellyfin-clusterjellyfin-workers

# Recreate workers
helm upgrade jellyfin clusterjellyfin/clusterjellyfin --namespace jellyfin-system
```

## Getting Help

### Collect Diagnostic Information

```bash
# Create diagnostic bundle
mkdir jellyfin-diagnostics
cd jellyfin-diagnostics

# Pod information
kubectl get pods -n jellyfin-system -o yaml > pods.yaml
kubectl describe pods -n jellyfin-system > pods-describe.txt

# Logs
kubectl logs -n jellyfin-system -l component=main --tail=1000 > main-logs.txt
kubectl logs -n jellyfin-system jellyfin-clusterjellyfin-workers-0 --tail=1000 > worker-logs.txt

# Storage
kubectl get pv,pvc -n jellyfin-system -o yaml > storage.yaml

# Events
kubectl get events -n jellyfin-system --sort-by='.lastTimestamp' > events.txt

# Configuration
helm get values jellyfin -n jellyfin-system > helm-values.yaml

# Create archive
tar -czf jellyfin-diagnostics.tar.gz *
```

### Support Channels

- **GitHub Issues**: https://github.com/celesrenata/clusterjellyfin/issues
- **Jellyfin Community**: https://jellyfin.org/docs/general/getting-help
- **Kubernetes Community**: https://kubernetes.io/community/

### Before Reporting Issues

1. Check this troubleshooting guide
2. Search existing GitHub issues
3. Collect diagnostic information
4. Include your configuration (sanitized)
5. Describe expected vs actual behavior
