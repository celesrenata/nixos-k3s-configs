#!/usr/bin/env bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install redis bitnami/redis -n redis-service -f values.yaml --create-namespace
kubectl apply -f service.yaml -n redis-service
