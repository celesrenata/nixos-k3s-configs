#!/usr/bin/env bash
helm repo add k8s-at-home https://k8s-at-home.com/charts/
helm repo update
kubectl create namespace radarr-service
helm upgrade -i -f values.radarr radarr k8s-at-home/radarr -n radarr-service 
kubectl apply -n radarr-service -f .
