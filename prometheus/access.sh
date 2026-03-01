#!/usr/bin/env bash
kubectl -n prometheus-service port-forward svc/prometheus-operated 9090:9090 2>&1 > /dev/null &
echo "http://127.0.0.1:9090"
