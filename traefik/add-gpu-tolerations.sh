#!/usr/bin/env bash
# Add GPU tolerations to Traefik components

echo "Adding GPU tolerations to Traefik deployment..."
kubectl patch deployment traefik -n kube-system --type='merge' -p='{"spec":{"template":{"spec":{"tolerations":[{"key":"nvidia.com/gpu","operator":"Equal","value":"present","effect":"NoSchedule"}]}}}}'

echo "Finding and patching Traefik service load balancer daemonset..."
SVCLB_NAME=$(kubectl get daemonsets -n kube-system | grep svclb-traefik | awk '{print $1}')
if [ -n "$SVCLB_NAME" ]; then
    echo "Patching daemonset: $SVCLB_NAME"
    kubectl patch daemonset $SVCLB_NAME -n kube-system --type='merge' -p='{"spec":{"template":{"spec":{"tolerations":[{"key":"nvidia.com/gpu","operator":"Equal","value":"present","effect":"NoSchedule"}]}}}}'
else
    echo "No svclb-traefik daemonset found"
fi

echo "Traefik GPU tolerations applied successfully"
