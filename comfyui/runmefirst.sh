#!/usr/bin/env bash
#git clone https://github.com/celesrenata/comfyui-onprem-k8s
#helm upgrade -i traefikcrds comfyui-onprem-k8s/charts/traefik
#helm upgrade -i comfyui comfyui-onprem-k8s/charts/comfyui \
#	--namespace comfyui-service \
#	--create-namespace \
#	-f values.yaml
kubectl create namespace comfyui-service
# You need me
kubectl apply -f middleware.yaml
kubectl apply -f . -n comfyui-service
