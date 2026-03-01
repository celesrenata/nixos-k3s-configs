#!/usr/bin/env bash
set -e

echo "Deploying LocalStack to k3s cluster..."

# Add LocalStack Helm repo
helm repo add localstack https://localstack.github.io/helm-charts
helm repo update

# Deploy LocalStack
helm upgrade -i localstack localstack/localstack \
  -n localstack-service \
  --create-namespace \
  -f values.yaml

echo "Waiting for LocalStack to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=localstack -n localstack-service --timeout=300s

echo "LocalStack deployed successfully!"
echo "Run ./access.sh to get connection details"
