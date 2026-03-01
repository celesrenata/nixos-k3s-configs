#!/usr/bin/env bash
helm repo add gpu-operator https://helm.ngc.nvidia.com/nvidia \
   && helm repo update
helm install --wait gpu-operator \
     -n gpu-operator --create-namespace \
     gpu-operator/gpu-operator \
      --set driver.enabled=true \
      --set toolkit.enabled=false
