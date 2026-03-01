#!/usr/bin/env bash
helm repo add localstack https://localstack.github.io/helm-charts
helm repo update
helm upgrade -i localstack localstack/localstack -n localstack-service --create-namespace -f values.yaml
