#!/usr/bin/env bash
helm uninstall wordpress --namespace wordpress
kubectl delete pvc -n wordpress --all --wait=false
kubectl patch pvc -n wordpress wordpress -p '{"metadata":{"finalizers":null}}' 2>/dev/null || true
kubectl delete volumes.longhorn.io -n longhorn-system pvc-* --field-selector metadata.namespace=wordpress 2>/dev/null || true
kubectl delete namespace wordpress
