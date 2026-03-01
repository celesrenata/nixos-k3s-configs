#!/usr/bin/env bash

# Create data directories
#sudo mkdir -p /kubedata-local/gitea /kubedata-local/registry
#sudo chown -R 1000:1000 /kubedata-local/gitea
#sudo chown -R 1000:1000 /kubedata-local/registry

# Create namespace and deploy
kubectl apply -f namespace.yaml
kubectl apply -f gitea-deployment.yaml
kubectl apply -f registry-deployment.yaml
kubectl apply -f registry-middleware.yaml
kubectl apply -f registry-transport.yaml
kubectl apply -f registry-certificate.yaml
kubectl apply -f registry-ingress.yaml

# Patch Traefik for large file uploads
kubectl patch deployment traefik -n kube-system --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--entryPoints.websecure.transport.respondingTimeouts.readTimeout=7200s"}]'
kubectl patch deployment traefik -n kube-system --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--entryPoints.websecure.transport.respondingTimeouts.writeTimeout=7200s"}]'
echo "Traefik patched with 2-hour timeouts"

# Add registry DNS to CoreDNS
kubectl patch configmap coredns -n kube-system --type merge -p '{"data":{"NodeHosts":"10.43.189.82 registry.celestium.life"}}'
kubectl rollout restart deployment/coredns -n kube-system

echo "Git server deployed in git-server namespace!"
echo "Gitea: http://NODE_IP:30300"
echo "Registry: NODE_IP:30500"
echo "Registry (secure): https://registry.celestium.life"
echo "SSH: ssh://git@NODE_IP:30022/user/repo.git"
