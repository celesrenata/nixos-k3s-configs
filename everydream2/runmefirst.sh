#!/usr/bin/env bash
kubectl create namespace everydream2-service
kubectl apply -f . -n everydream2-service
