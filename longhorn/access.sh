#!/usr/bin/env bash
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8081:80 2>&1 > /dev/null &
echo "http://127.0.0.1:8081"
