#!/usr/bin/env bash
# Get LoadBalancer IP (k3s uses metallb or similar)
export EXTERNAL_IP=$(kubectl get svc localstack -n localstack-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)

if [ -z "$EXTERNAL_IP" ]; then
    # Fallback to cluster IP if LoadBalancer not available
    export EXTERNAL_IP=$(kubectl get svc localstack -n localstack-service -o jsonpath='{.spec.clusterIP}')
    echo "Using ClusterIP: http://$EXTERNAL_IP:4566"
else
    echo "LoadBalancer IP: http://$EXTERNAL_IP:4566"
fi

# Also show ingress access
echo "Ingress access: https://aws.celestium.life"
