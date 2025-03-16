#!/usr/bin/env bash
kubectl create namespace steamvr-service
kubectl apply -f . -n steamvr-service
kubectl apply -f snapshot.yaml
