#!/usr/bin/env bash
kubectl -n kube-system port-forward svc/headlamp 8080:80 2>&1 > /dev/null &
kubectl get secret celes-admin -n kube-system -o jsonpath={".data.token"} | base64 -d
echo
echo "http://127.0.0.1:8080"
