#!/usr/bin/env bash

echo "=== SteamVR Kubernetes Cleanup ==="
echo "Removing SteamVR deployment and resources..."

NAMESPACE="steamvr-service"

# Delete all resources in the namespace
echo "Deleting all resources in namespace: $NAMESPACE"
kubectl delete -f deployment.yaml -n "$NAMESPACE" 2>/dev/null || true
kubectl delete -f service.yaml -n "$NAMESPACE" 2>/dev/null || true
kubectl delete -f configmap-createusers.yaml -n "$NAMESPACE" 2>/dev/null || true
kubectl delete -f secret-auth.yaml -n "$NAMESPACE" 2>/dev/null || true
kubectl delete -f nfs-pvc.yaml -n "$NAMESPACE" 2>/dev/null || true
kubectl delete -f nfs-pv.yaml -n "$NAMESPACE" 2>/dev/null || true
kubectl delete -f snapshot.yaml -n "$NAMESPACE" 2>/dev/null || true

# Wait a moment for resources to be deleted
echo "Waiting for resources to be deleted..."
sleep 5

# Delete the namespace (this will also delete any remaining resources)
echo "Deleting namespace: $NAMESPACE"
kubectl delete namespace "$NAMESPACE" 2>/dev/null || true

echo ""
echo "=== Cleanup Complete! ==="
echo "All SteamVR resources have been removed."
