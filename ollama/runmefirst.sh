#!/usr/bin/env bash
helm repo add ollama-helm https://otwld.github.io/ollama-helm/
helm repo update
helm upgrade -i ollama ollama-helm/ollama \
       --namespace ollama-service \
       --create-namespace \
       --values values.yaml
kubectl apply -f . -n ollama-service
