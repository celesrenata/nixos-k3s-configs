#!/usr/bin/env bash
helm repo add nvdp https://nvidia.github.io/k8s-device-plugin
helm repo add gpu-helm-charts https://nvidia.github.io/dcgm-exporter/helm-charts
helm repo update

kubectl apply -f runtime.yaml
kubectl label nodes gremlin-1 nvidia.com/gpu.present=true
helm upgrade -i nvdp nvdp/nvidia-device-plugin \
                                      --version=0.17.0 \
                                      --namespace nvidia-device-plugin \
                                      --create-namespace \
                                      --set gfd.enabled=true \
				      --set runtimeClassName=nvidia \
				      --set-file config.map.config=mps.yaml

helm upgrade -i dcgm-exporter gpu-helm-charts/dcgm-exporter \
	                              --namespace dcgm-exporter \
				      --create-namespace

kubectl expose service dcgm-exporter --type=LoadBalancer --name=dcgm-exporter-lb -n dcgm-exporter
