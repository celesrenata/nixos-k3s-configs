#!/usr/bin/env bash
kubectl create namespace startup-hastebin
kubectl kustomize . | kubectl create -n startup-hastebin -f -
kubectl apply -f ingress.yaml -n startup-hastebin
