#!/usr/bin/env bash
set -e

echo "=== NVIDIA Device Plugin Setup ==="
echo ""

echo "Step 1: Labeling GPU node..."
kubectl label node gremlin-1 nvidia.com/gpu.present=true --overwrite

echo "Step 2: Adding helm repos..."
helm repo add nvdp https://nvidia.github.io/k8s-device-plugin 2>/dev/null || true
helm repo add gpu-helm-charts https://nvidia.github.io/dcgm-exporter/helm-charts 2>/dev/null || true
helm repo update

echo "Step 3: Installing NVIDIA device plugin..."
helm upgrade --install nvdp nvdp/nvidia-device-plugin \
  -n nvidia-device-plugin \
  --create-namespace \
  -f nvidia-device-plugin-values.yaml

echo "Step 4: Patching daemonset with volume mounts..."
sleep 3
kubectl patch daemonset nvdp-nvidia-device-plugin -n nvidia-device-plugin --patch-file daemonset-patch.yaml

echo "Step 5: Waiting for device plugin to be ready..."
sleep 60

echo "Step 6: Verifying GPU capacity..."
GPU_COUNT=$(kubectl get node gremlin-1 -o json | jq -r '.status.capacity["nvidia.com/gpu"]')
echo "GPU capacity: $GPU_COUNT (expected: 10 with time slicing)"

echo ""
echo "=== Installing DCGM Exporter ==="
helm upgrade -i dcgm-exporter gpu-helm-charts/dcgm-exporter \
  --namespace dcgm-exporter \
  --create-namespace \
  --set runtimeClassName=nvidia

sleep 10

echo "Patching DCGM exporter for nvidia runtime, gremlin-1 only, increased memory, and 10s interval..."
kubectl patch daemonset dcgm-exporter -n dcgm-exporter --type='json' -p='[
  {"op": "add", "path": "/spec/template/spec/runtimeClassName", "value": "nvidia"},
  {"op": "add", "path": "/spec/template/spec/nodeSelector", "value": {"kubernetes.io/hostname": "gremlin-1"}},
  {"op": "add", "path": "/spec/template/spec/containers/0/resources/limits/nvidia.com~1gpu", "value": "1"},
  {"op": "replace", "path": "/spec/template/spec/containers/0/resources/limits/memory", "value": "1Gi"},
  {"op": "replace", "path": "/spec/template/spec/containers/0/resources/requests/memory", "value": "512Mi"}
]'

kubectl set env daemonset/dcgm-exporter -n dcgm-exporter DCGM_EXPORTER_INTERVAL=5000

# Fix ServiceMonitor scrape interval to match DCGM collection interval
kubectl patch servicemonitor dcgm-exporter -n dcgm-exporter --type='json' -p='[{"op": "replace", "path": "/spec/endpoints/0/interval", "value": "5s"}]' 2>/dev/null || true

kubectl expose service dcgm-exporter --type=LoadBalancer --name=dcgm-exporter-lb -n dcgm-exporter 2>/dev/null || true

echo "Waiting for DCGM exporter..."
kubectl rollout status daemonset/dcgm-exporter -n dcgm-exporter --timeout=120s

echo ""
echo "=== Setup Complete ==="
echo "DCGM Exporter metrics: http://10.1.1.12:9400/metrics"
