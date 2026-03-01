#!/usr/bin/env bash

echo "=== Fixing WordPress LoadBalancer Port Conflicts ==="

# Delete the problematic LoadBalancer service
echo "Removing problematic WordPress LoadBalancer service..."
kubectl delete svc wordpress -n wordpress --ignore-not-found=true

# Wait for the svclb pods to be cleaned up
echo "Waiting for svclb cleanup..."
sleep 10

# Apply the fixed NodePort service
echo "Applying fixed WordPress NodePort service..."
kubectl apply -f fix-wordpress-service.yaml

# Update the WordPress deployment to use the correct service type
echo "Updating WordPress helm deployment..."
helm upgrade wordpress oci://registry-1.docker.io/bitnamicharts/wordpress \
	--namespace wordpress \
	--reuse-values \
	--set service.type=NodePort \
	--set service.nodePorts.http=30080 \
	--set service.nodePorts.https=30443

echo "Checking WordPress service status..."
kubectl get svc -n wordpress

echo "Checking for any remaining svclb pods..."
kubectl get pods -n kube-system | grep svclb-wordpress || echo "No WordPress svclb pods found (good!)"

echo "=== WordPress LoadBalancer fix complete! ==="
echo "WordPress is now accessible via NodePort:"
echo "- HTTP: http://10.1.1.12:30080 (or any node IP)"
echo "- HTTPS: https://10.1.1.12:30443 (or any node IP)"
echo "- Ingress still works via: wordpress.celestium.life"
