#!/usr/bin/env bash
helm repo add portainer https://portainer.github.io/k8s/
helm repo update
helm upgrade --install --create-namespace -n portainer portainer portainer/portainer \
    --set service.type=ClusterIP \
    --set tls.force=false \
    --set ingress.enabled=false
kubectl apply -n portainer -f ingress.yaml

#    --set ingress.ingressClassName=traefik \
#    --set ingress.annotations."traefik\.ingress\.kubernetes\.io/router\.entrypoints"=websecure \
#    --set ingress.annotations."cert-manager\.io/cluster-issuer"=ca-issuer \
#    --set ingress.hosts[0].host=portainer.celestium.life \
#    --set ingress.hosts[0].paths[0].path="/"
