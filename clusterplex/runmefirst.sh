#!/usr/bin/env bash
helm repo add clusterplex http://pabloromeo.github.io/clusterplex
kubectl create namespace plex-system
kubectl apply -n plex-system -f clusterplex-ingress-https.yaml
kubectl apply -n plex-system -f nfs-pv.yaml
kubectl apply -n plex-system -f nfs-pvc.yaml
kubectl apply -n plex-system -f transcode-pvc.yaml
echo -en "\e[31mEnter plex claim token from https://www.plex.tv/claim/\e[0m: "
read plexclaim
sed -i '$ d' plex-secret.yaml
echo "  claim_token: ${plexclaim}" >> plex-secret.yaml
kubectl apply -n plex-system -f plex-secret.yaml

helm install clusterplex clusterplex/clusterplex -n plex-system -f values.yaml
kubectl expose deployment clusterplex-pms --type=LoadBalancer --name=plex-lb -n plex-system
