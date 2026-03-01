#!/usr/bin/env bash
helm repo add kubeai https://www.kubeai.org
helm repo update
kubectl create namespace kubeai-service
helm upgrade -i kubeai kubeai/kubeai \
       --values values.yaml \
       --wait \
       --timeout 10m \
       --namespace kubeai-service
