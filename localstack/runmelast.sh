#!/usr/bin/env bash
helm uninstall localstack -n localstack-service
kubectl delete namespace localstack-service
