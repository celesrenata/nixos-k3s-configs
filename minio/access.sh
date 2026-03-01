#!/usr/bin/env bash
kubectl port-forward -n minio-service svc/minio-crawler-hl  9000:9000 2>&1 > /dev/null &
echo "service now available on localhost on port 9000"
