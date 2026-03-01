#!/usr/bin/env bash
helm repo add pajikos http://pajikos.github.io/home-assistant-helm-chart/
helm repo update
helm upgrade --install home-assistant pajikos/home-assistant -n homeassistant-service --create-namespace -f values.yaml
kubectl apply -n homeassistant-service -f .
kubectl create configmap hass-configuration --from-file=configuration.yaml -n homeassistant-service --dry-run=client -o yaml | kubectl replace -f -
kubectl rollout restart statefulset/home-assistant -n homeassistant-service
