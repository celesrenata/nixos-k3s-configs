#!/usr/bin/env bash
helm repo add nvdp https://nvidia.github.io/k8s-device-plugin
helm repo update

kubectl apply -f runtime.yaml
kubectl label nodes gremlin-1 nvidia.com/gpu.present=true
helm upgrade -i nvdp nvdp/nvidia-device-plugin \
                                      --version=0.16.2 \
                                      --namespace nvidia-device-plugin \
                                      --create-namespace \
                                      --set gfd.enabled=true \
				      --set runtimeClassName=nvidia \
				      --set-file config.map.config=time-slice.yaml
