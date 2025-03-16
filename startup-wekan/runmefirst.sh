#!/usr/bin/env bash
helm repo add wekan https://wekan.github.io/charts
kubectl create namespace startup-wekan

helm install startup-wekan wekan/wekan --namespace startup-wekan -f values.yaml
kubectl apply -f . -n startup-wekan
