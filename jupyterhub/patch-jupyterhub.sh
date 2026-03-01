#!/usr/bin/env bash
set -e

echo "Patching JupyterHub to disable init containers..."

# Wait for hub pod to be ready
kubectl wait --for=condition=ready pod -l app=jupyterhub,component=hub -n jupyterhub-service --timeout=120s

# Create a custom config that disables init containers
kubectl create configmap hub-config-patch -n jupyterhub-service --from-literal=patch.py='
c.KubeSpawner.init_containers = []
' --dry-run=client -o yaml | kubectl apply -f -

# Patch the hub deployment to use our config
kubectl patch deployment hub -n jupyterhub-service --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/volumes/-",
    "value": {"name": "config-patch", "configMap": {"name": "hub-config-patch"}}
  },
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/volumeMounts/-", 
    "value": {"name": "config-patch", "mountPath": "/usr/local/etc/jupyterhub/patch.py", "subPath": "patch.py"}
  },
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/args",
    "value": ["jupyterhub", "--config", "/usr/local/etc/jupyterhub/jupyterhub_config.py", "--config", "/usr/local/etc/jupyterhub/patch.py"]
  }
]'

echo "JupyterHub patched! Restarting hub pod..."
kubectl delete pod -l app=jupyterhub,component=hub -n jupyterhub-service

echo "Patch complete!"
