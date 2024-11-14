#!/usr/bin/env bash
kubectl create namespace longhorn-system
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
helm install kyverno kyverno/kyverno -n kyverno --create-namespace
helmfile apply
#helm uninstall longhorn -n longhorn
kubectl delete namespace longhorn-system
echo "now we wait 10"
sleep 10
helmfile apply
#kubectl apply -n longhorn-system -f ingress.yaml
echo "giving longhorn time to spin up, 90"
sleep 90 
