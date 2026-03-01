#!/bin/bash
set -e

# Label GPU node
kubectl label node gremlin-1 nvidia.com/gpu.present=true --overwrite

# Add helm repo
helm repo add nvdp https://nvidia.github.io/k8s-device-plugin
helm repo update

# Install device plugin
helm install nvdp nvdp/nvidia-device-plugin \
  -n nvidia-device-plugin \
  --create-namespace \
  -f nvidia-device-plugin-values.yaml

echo "Waiting for device plugin to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=nvidia-device-plugin -n nvidia-device-plugin --timeout=60s

echo "Verifying GPU capacity..."
kubectl get node gremlin-1 -o json | jq '.status.capacity["nvidia.com/gpu"]'
