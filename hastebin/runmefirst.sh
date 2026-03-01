#!/usr/bin/env bash
kubectl create namespace docker-hastebin1
kubectl kustomize . | kubectl create -n docker-hastebin1 -f -
kubectl apply -f ingress.yaml -n docker-hastebin1
