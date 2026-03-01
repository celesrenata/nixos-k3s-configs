#!/usr/bin/env bash
# Add headlamp repository (official replacement for kubernetes-dashboard)
helm repo add headlamp https://kubernetes-sigs.github.io/headlamp/
helm repo update
# Deploy Headlamp
helm upgrade --install headlamp headlamp/headlamp --create-namespace --namespace kube-system
kubectl apply -f ../dashboard
