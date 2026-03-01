#!/bin/bash

echo "=== KUBERNETES CLUSTER HEALTH ANALYSIS ==="
echo "Generated on: $(date)"
echo ""

echo "=== CLUSTER OVERVIEW ==="
kubectl cluster-info
echo ""

echo "=== NODE STATUS ==="
kubectl get nodes -o wide
echo ""

echo "=== NODE RESOURCE USAGE ==="
kubectl top nodes
echo ""

echo "=== NAMESPACE OVERVIEW ==="
kubectl get namespaces | wc -l | xargs echo "Total Namespaces:"
kubectl get namespaces
echo ""

echo "=== POD STATUS SUMMARY ==="
echo "Total Pods:"
kubectl get pods --all-namespaces | wc -l
echo ""
echo "Running Pods:"
kubectl get pods --all-namespaces --field-selector=status.phase=Running | wc -l
echo ""
echo "Failed/Problematic Pods:"
kubectl get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded
echo ""

echo "=== TOP MEMORY CONSUMERS ==="
kubectl top pods --all-namespaces --sort-by=memory | head -15
echo ""

echo "=== TOP CPU CONSUMERS ==="
kubectl top pods --all-namespaces --sort-by=cpu | head -15
echo ""

echo "=== GPU UTILIZATION ==="
echo "GPU-enabled pods:"
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.spec.containers[*].resources.limits.nvidia\.com/gpu}{"\n"}{end}' | grep -E '[0-9]+$' | wc -l
echo ""
echo "GPU pods details:"
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.spec.containers[*].resources.limits.nvidia\.com/gpu}{"\n"}{end}' | grep -E '[0-9]+$'
echo ""

echo "=== STORAGE ANALYSIS ==="
echo "Total Persistent Volumes:"
kubectl get pv | wc -l
echo ""
echo "Storage by type:"
kubectl get pv -o jsonpath='{range .items[*]}{.spec.storageClassName}{"\n"}{end}' | sort | uniq -c
echo ""
echo "Large volumes (>100Gi):"
kubectl get pv -o custom-columns=NAME:.metadata.name,CAPACITY:.spec.capacity.storage,STORAGECLASS:.spec.storageClassName | grep -E '[0-9]{3,}Gi|[0-9]+Ti'
echo ""

echo "=== RECENT EVENTS (WARNINGS/ERRORS) ==="
kubectl get events --all-namespaces --field-selector type!=Normal --sort-by='.lastTimestamp' | tail -20
echo ""

echo "=== LONGHORN STORAGE HEALTH ==="
kubectl get pods -n longhorn-system | grep -v Running | wc -l | xargs echo "Non-running Longhorn pods:"
echo ""

echo "=== NETWORK ISSUES ==="
echo "Pending LoadBalancer services:"
kubectl get svc --all-namespaces --field-selector spec.type=LoadBalancer | grep -c Pending
echo ""

echo "=== RESTART ANALYSIS ==="
echo "Pods with high restart counts (>5):"
kubectl get pods --all-namespaces -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.status.containerStatuses[0].restartCount}{"\n"}{end}' | awk '$3 > 5' | head -10
echo ""

echo "=== RESOURCE QUOTAS ==="
kubectl get resourcequotas --all-namespaces
echo ""

echo "=== INGRESS STATUS ==="
kubectl get ingress --all-namespaces
echo ""

echo "=== CERTIFICATE STATUS ==="
kubectl get certificates --all-namespaces 2>/dev/null || echo "No cert-manager certificates found"
echo ""

echo "=== ANALYSIS COMPLETE ==="
