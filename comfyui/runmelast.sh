#!/usr/bin/env bash
helm uninstall ollama --namespace comfyui-servicee
kubectl delete -f . -n comfyui-service
