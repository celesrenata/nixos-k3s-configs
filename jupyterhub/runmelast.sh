#!/usr/bin/env bash

echo "Uninstalling JupyterHub..."

helm uninstall jupyterhub -n jupyterhub-service

echo "JupyterHub uninstalled!"
