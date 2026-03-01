#!/usr/bin/env bash
kubectl create namespace blender-service
kubectl apply -f . -n blender-service
kubectl apply -f snapshot.yaml
