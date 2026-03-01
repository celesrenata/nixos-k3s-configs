#!/usr/bin/env bash
kubectl create namespace kyverno
kubectl create namespace longhorn-system
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update

# Delete old Kyverno CRDs if they exist to avoid version migration issues
kubectl delete crd globalcontextentries.kyverno.io imagevalidatingpolicies.policies.kyverno.io policyexceptions.policies.kyverno.io validatingpolicies.policies.kyverno.io 2>/dev/null || true

helmfile sync --skip-schema-validation
echo "giving longhorn time to spin up, 90"
sleep 90 
kubectl apply -f local-storage.yaml
