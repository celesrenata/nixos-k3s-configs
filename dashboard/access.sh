#!/usr/bin/env bash
kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443 2>&1 > /dev/null &
kubectl get secret celes-admin -n kubernetes-dashboard -o jsonpath={".data.token"} | base64 -d
echo
echo "https://127.0.0.1:8443"
