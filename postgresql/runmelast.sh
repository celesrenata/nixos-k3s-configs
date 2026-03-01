#!/usr/bin/env bash
kubectl delete -n postgresql-service -f .
kubectl delete namespace postgresql-service
helm uninstall cnpg --namespace cnpg-system
kubectl delete namespace cnpg-system
