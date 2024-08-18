#!/usr/bin/env bash
kubectl create namespace vms
kubectl apply -f . -n vms
