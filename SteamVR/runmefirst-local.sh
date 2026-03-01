#!/usr/bin/env bash

echo "=== SteamVR Kubernetes Deployment (Local Registry) ==="
echo "Setting up SteamVR with password authentication..."

# Create namespace
echo "Creating namespace: steamvr-service"
kubectl create namespace steamvr-service --dry-run=client -o yaml | kubectl apply -f -

# Apply the ConfigMap for user creation first
echo "Creating ConfigMap for user creation..."
kubectl apply -f configmap-createusers.yaml -n steamvr-service

# Apply the Secret for web authentication
echo "Creating Secret for web authentication..."
kubectl apply -f secret-auth.yaml -n steamvr-service

# Apply storage resources (PVs, PVCs)
echo "Creating storage resources..."
if [ -f nfs-pv.yaml ]; then
    echo "  - Applying Persistent Volumes..."
    kubectl apply -f nfs-pv.yaml -n steamvr-service
fi

if [ -f nfs-pvc.yaml ]; then
    echo "  - Applying Persistent Volume Claims..."
    kubectl apply -f nfs-pvc.yaml -n steamvr-service
fi

# Create temporary deployment file with local registry
echo "Creating SteamVR deployment (using local registry)..."
sed 's|ghcr.io/celesrenata/steamvr:latest|registry.celestium.life/celesrenata/steamvr:latest|g' deployment.yaml > deployment-local.yaml
kubectl apply -f deployment-local.yaml -n steamvr-service

# Apply the service
if [ -f service.yaml ]; then
    echo "Creating service..."
    kubectl apply -f service.yaml -n steamvr-service
fi

# Apply snapshot configuration
echo "Applying snapshot configuration..."
if kubectl apply -f snapshot.yaml -n steamvr-service 2>/dev/null; then
    echo "✅ Snapshot configuration applied"
else
    echo "⚠️  Snapshot configuration failed (Longhorn may not be installed)"
fi

echo ""
echo "=== Deployment Complete! ==="
echo ""
echo "Using local registry: registry.celestium.life/celesrenata/steamvr:latest"
echo ""
echo "Password authentication is configured:"
echo "- Web UI username: celes"
echo "- Web UI password: renata"
echo "- Linux user: celes (password: renata, sudo access: yes)"
echo ""
echo "Useful commands:"
echo "  Check deployment status:"
echo "    kubectl get pods -l io.kompose.service=steamvr -n steamvr-service"
echo ""
echo "  Get service details:"
echo "    kubectl get svc steamvr -n steamvr-service"
echo ""
echo "  View logs:"
echo "    kubectl logs -l io.kompose.service=steamvr -n steamvr-service -f"
echo ""
echo "  To change passwords later:"
echo "    ./update-password.sh <username> <password>"
echo ""
echo "Waiting for pod to be ready..."
if kubectl wait --for=condition=ready pod -l io.kompose.service=steamvr -n steamvr-service --timeout=300s 2>/dev/null; then
    echo "✅ Pod is ready!"
else
    echo "⚠️  Pod not ready yet. Check status with:"
    echo "    kubectl get pods -n steamvr-service"
    echo "    kubectl describe pod -l io.kompose.service=steamvr -n steamvr-service"
fi
