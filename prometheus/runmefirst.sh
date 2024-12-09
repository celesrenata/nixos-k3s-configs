#!/usr/bin/env bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade -i prometheus prometheus-community/kube-prometheus-stack -n prometheus-service --create-namespace -f values.yaml
#kubectl apply -f ingress.yaml -n prometheus-service


