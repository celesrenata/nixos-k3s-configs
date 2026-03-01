#!/usr/bin/env bash
kubectl create namespace onetrainer-service
kubectl apply -f . -n onetrainer-service
kubectl apply -f snapshot.yaml
