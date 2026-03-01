#!/bin/bash

# Patch JupyterHub to remove the problematic init container
echo "Patching JupyterHub to remove cloud metadata init container..."

# Wait for hub pod to be ready
kubectl wait --for=condition=ready pod -l app=jupyterhub,component=hub -n jupyterhub-service --timeout=120s

# Patch the hub configmap to disable cloud metadata blocking
kubectl patch configmap hub -n jupyterhub-service --type='merge' -p='{"data":{"jupyterhub_config.py":"c.KubeSpawner.init_containers = []\nc.JupyterHub.spawner_class = \"kubespawner.KubeSpawner\"\nc.KubeSpawner.image = \"jupyter/datascience-notebook:latest\"\nc.KubeSpawner.start_timeout = 300\nc.KubeSpawner.http_timeout = 120\nc.Authenticator.admin_users = {\"celes\"}\nc.DummyAuthenticator.password = \"password\"\nc.JupyterHub.authenticator_class = \"jupyterhub.auth.DummyAuthenticator\"\n"}}'

# Restart hub pod to apply changes
kubectl delete pod -l app=jupyterhub,component=hub -n jupyterhub-service

# Wait for hub to come back up
kubectl wait --for=condition=ready pod -l app=jupyterhub,component=hub -n jupyterhub-service --timeout=120s

echo "JupyterHub patched successfully!"
