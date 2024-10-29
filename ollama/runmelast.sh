#!/usr/bin/env bash
helm uninstall ollama --namespace ollama-service
kubectl delete -f . -n ollama-service
