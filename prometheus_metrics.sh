#!/bin/bash

PROMETHEUS_URL="http://10.43.86.148:9090"

echo "=== PROMETHEUS METRICS ANALYSIS ==="
echo "Generated on: $(date)"
echo ""

echo "=== CLUSTER RESOURCE UTILIZATION ==="
echo "CPU Usage by Node:"
kubectl run temp-curl --rm -i --tty --image=curlimages/curl --restart=Never -- curl -s "${PROMETHEUS_URL}/api/v1/query?query=100-(avg(irate(node_cpu_seconds_total{mode=\"idle\"}[5m]))*100)" | jq -r '.data.result[] | "\(.metric.instance): \(.value[1])%"' 2>/dev/null || echo "CPU metrics not available"

echo ""
echo "Memory Usage by Node:"
kubectl run temp-curl --rm -i --tty --image=curlimages/curl --restart=Never -- curl -s "${PROMETHEUS_URL}/api/v1/query?query=(1-(node_memory_MemAvailable_bytes/node_memory_MemTotal_bytes))*100" | jq -r '.data.result[] | "\(.metric.instance): \(.value[1])%"' 2>/dev/null || echo "Memory metrics not available"

echo ""
echo "=== STORAGE METRICS ==="
echo "Disk Usage by Node:"
kubectl run temp-curl --rm -i --tty --image=curlimages/curl --restart=Never -- curl -s "${PROMETHEUS_URL}/api/v1/query?query=(1-(node_filesystem_avail_bytes{fstype!=\"tmpfs\"}/node_filesystem_size_bytes{fstype!=\"tmpfs\"}))*100" | jq -r '.data.result[] | "\(.metric.instance) \(.metric.mountpoint): \(.value[1])%"' 2>/dev/null || echo "Disk metrics not available"

echo ""
echo "=== NETWORK METRICS ==="
echo "Network I/O (bytes/sec):"
kubectl run temp-curl --rm -i --tty --image=curlimages/curl --restart=Never -- curl -s "${PROMETHEUS_URL}/api/v1/query?query=rate(node_network_receive_bytes_total[5m])" | jq -r '.data.result[] | "\(.metric.instance) \(.metric.device) RX: \(.value[1]) bytes/sec"' 2>/dev/null | head -10 || echo "Network metrics not available"

echo ""
echo "=== POD METRICS ==="
echo "Top CPU consuming pods:"
kubectl run temp-curl --rm -i --tty --image=curlimages/curl --restart=Never -- curl -s "${PROMETHEUS_URL}/api/v1/query?query=topk(10,rate(container_cpu_usage_seconds_total{container!=\"POD\",container!=\"\"}[5m]))" | jq -r '.data.result[] | "\(.metric.namespace)/\(.metric.pod): \(.value[1])"' 2>/dev/null || echo "Pod CPU metrics not available"

echo ""
echo "Top Memory consuming pods:"
kubectl run temp-curl --rm -i --tty --image=curlimages/curl --restart=Never -- curl -s "${PROMETHEUS_URL}/api/v1/query?query=topk(10,container_memory_usage_bytes{container!=\"POD\",container!=\"\"})" | jq -r '.data.result[] | "\(.metric.namespace)/\(.metric.pod): \(.value[1] | tonumber / 1024 / 1024 | floor)MB"' 2>/dev/null || echo "Pod memory metrics not available"

echo ""
echo "=== ANALYSIS COMPLETE ==="
