#!/usr/bin/env bash
#git clone https://github.com/celesrenata/comfyui-onprem-k8s
#helm upgrade -i traefikcrds comfyui-onprem-k8s/charts/traefik
#helm upgrade -i comfyui comfyui-onprem-k8s/charts/comfyui \
#	--namespace comfyui-service \
#	--create-namespace \
#	-f values.yaml
ssh root@gremlin-1 "mkdir -p /mnt/local-storage/comfyui/{models,tmp,user,custom-nodes,venv} && chown -R 1000:1000 /mnt/local-storage/comfyui/"
kubectl create namespace comfyui-service
# You need me
kubectl apply -f middleware.yaml
kubectl apply -f local-storage-pvs.yaml
kubectl apply -f local-storage-pvcs.yaml
kubectl apply -f serviceaccount.yaml -n comfyui-service
kubectl apply -f service.yaml -n comfyui-service
kubectl apply -f deployment.yaml -n comfyui-service
kubectl apply -f ingress.yaml -n comfyui-service
