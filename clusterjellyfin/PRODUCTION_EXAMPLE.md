# ClusterJellyfin Production Example

## Architecture

```
┌─────────────────────────────────────┐
│          Ingress Controller         │
│        (Traefik/NGINX)              │
└─────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────┐
│ Main Jellyfin Pod (Web UI & API)    │
│ ↔ PostgreSQL Database (DB Pod)      │
└─────────────────────────────────────┘
              │
              ▼
┌───────────────────────────────────────────┐
│ Worker Pods (3) - Distributed Transcoders │
└───────────────────────────────────────────┘
```

## Key Features

- ✅ **Ingress Controller**: Dedicated controller for external traffic routing (Traefik/NGINX)
- ✅ **PostgreSQL Database Pod**: Dedicated database pod for production use
- ✅ **Main Jellyfin Pod**: Single pod handling web UI and API orchestration
- ✅ **Distributed Transcoding**: Three worker pods handling all transcoding tasks
- ✅ **Bidirectional Database Connection**: Arrows between Main and DB show bidirectional communication
- ✅ **Scalable Architecture**: Easily add more worker pods as needed

## Configuration Highlights

### Ingress Configuration
```yaml
ingress:
  enabled: true
  className: "nginx"  # or "traefik"
  hosts:
    - host: "jellyfin.yourdomain.com"
      paths:
        - path: "/"
          pathType: "Prefix"
```

### PostgreSQL Setup
```yaml
postgresql:
  enabled: true
  internal:
    resources:
      requests:
        memory: "512Mi"
        cpu: "250m"
      limits:
        memory: "1Gi"
        cpu: "500m"
```

### Worker Configuration (3 Pods)
```yaml
workers:
  replicas: 3
  resources:
    requests:
      cpu: "2000m"
      memory: "4Gi"
    limits:
      cpu: "4000m"
      memory: "8Gi"
```

## Verification Steps

### Check Ingress Status
```bash
kubectl get ingress -n jellyfin-system
```

Expected output:
```
NAME                  CLASS    HOSTS                  ADDRESS   PORTS   AGE
jellyfin-ingress      nginx    jellyfin.yourdomain.com             80      2m
```

### Verify Database Connection
```bash
kubectl logs -n jellyfin-system -l component=main | grep -i postgres
```

Expected output:
```
PostgreSQL connection established
```

### Test Distributed Transcoding
```bash
kubectl exec -n jellyfin-system deployment/jellyfin-clusterjellyfin-main -- \
  /shared/rffmpeg -f lavfi -i testsrc=duration=1:size=320x240:rate=1 -c:v libx264 -f null -
```

Expected output:
```
Transcoding task distributed across 3 worker pods
