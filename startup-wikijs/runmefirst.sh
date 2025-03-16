#!/usr/bin/env bash
helm repo add requarks https://charts.js.wiki
kubectl create namespace startup-wikijs
kubectl apply -f . -n startup-wikijs
helm install startup-wikijs requarks/wiki \
	--namespace startup-wikijs \
	-f values.yaml
