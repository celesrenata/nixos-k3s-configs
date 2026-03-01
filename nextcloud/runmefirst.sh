#!/usr/bin/env bash
helm repo add nextcloud https://nextcloud.github.io/helm/
kubectl create namespace nextcloud
kubectl apply -f . -n nextcloud
helm upgrade --install nextcloud nextcloud/nextcloud \
	--namespace nextcloud \
	-f values.yaml
