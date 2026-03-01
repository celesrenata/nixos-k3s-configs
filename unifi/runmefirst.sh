#!/usr/bin/env bash
kubectl create namespace unifi-service
kubectl apply -k config/rbac/  --namespace unifi-service
kubectl apply -f mongo.yaml -n unifi-service 
echo "Creating mongodb"
sleep 60
kubectl kustomize . | kubectl create -n unifi-service -f -
