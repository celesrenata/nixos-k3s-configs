#!/bin/bash

# ClusterJellyfin Installation Script

set -e

NAMESPACE=${NAMESPACE:-jellyfin}
RELEASE_NAME=${RELEASE_NAME:-jellyfin}
CHART_PATH=${CHART_PATH:-./charts/clusterjellyfin}

echo "Installing ClusterJellyfin..."
echo "Namespace: $NAMESPACE"
echo "Release: $RELEASE_NAME"
echo "Chart: $CHART_PATH"

# Create namespace if it doesn't exist
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Install or upgrade the Helm chart
helm upgrade --install $RELEASE_NAME $CHART_PATH \
  --namespace $NAMESPACE \
  --create-namespace \
  "$@"

echo ""
echo "ClusterJellyfin installed successfully!"
echo ""
echo "To access Jellyfin:"
echo "  kubectl port-forward -n $NAMESPACE svc/${RELEASE_NAME}-clusterjellyfin-main 8096:8096"
echo ""
echo "Then open: http://localhost:8096"
