#!/usr/bin/env bash
helm uninstall ollama --namespace onetrainer-servicee
kubectl delete -f . -n onetrainer-service
