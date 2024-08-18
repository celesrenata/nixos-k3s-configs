#!/usr/bin/env bash
kubectl create namespace unifi-service
kubectl kustomize . | kubectl create -n unifi-service -f -
