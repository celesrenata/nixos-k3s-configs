#!/usr/bin/env bash
kubectl port-forward -n kubevirt-manager svc/kubevirt-manager 8080:8080 2>&1 > /dev/null &
echo "http://127.0.0.1:8080"
