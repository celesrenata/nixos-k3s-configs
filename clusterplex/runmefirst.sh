#!/usr/bin/env bash
helm repo add clusterplex http://pabloromeo.github.io/clusterplex
kubectl create namespace plex-system
kubectl apply -n plex-system -f clusterplex-ingress-https.yaml
kubectl apply -n plex-system -f nfs-pv.yaml
kubectl apply -n plex-system -f nfs-pvc.yaml
echo -en "\e[31mEnter plex claim token from https://www.plex.tv/claim/\e[0m: "
read plexclaim
helm install clusterplex clusterplex/clusterplex -n plex-system \
        --set global.sharedStorage.media.existingClaim=clusterplex-media-pvc \
	--set pms.configVolume.existingClaim=clusterplex-config-pvc \
        --set pms.config.plexClaimToken=${plexclaim}
kubectl expose deployment clusterplex-pms --type=LoadBalancer --name=plex-lb -n plex-system
