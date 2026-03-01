#!/usr/bin/env bash
kubectl create namespace netbootxyz-service
kubectl apply -f . --namespace netbootxyz-service
kubectl expose deployment netbootxyz --type=NodePort --name=netbootxyz-lb -n netbootxyz-service --protocol UDP --port=69 --target-port=69
