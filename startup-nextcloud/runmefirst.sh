#!/usr/bin/env bash
helm repo add nextcloud https://nextcloud.github.io/helm/
kubectl create namespace startup-nextcloud
kubectl apply -f . -n startup-nextcloud
helm upgrade --install startup-nextcloud nextcloud/nextcloud \
	--namespace startup-nextcloud \
	-f values.yaml
