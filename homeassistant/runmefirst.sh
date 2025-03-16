#!/usr/bin/env bash
helm repo add pajikos http://pajikos.github.io/home-assistant-helm-chart/
helm repo update
helm install home-assistant pajikos/home-assistant -n homeassistant-service --create-namespace -f values.yaml
kubectl apply -n homeassistant-service -f .
