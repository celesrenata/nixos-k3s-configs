#!/usr/bin/env bash
kubectl --namespace kube-system \
    get deployment traefik -o yaml | \
    yq '.spec.template.spec.containers.0.args' | \
    grep -- '--providers.kubernetescrd'
