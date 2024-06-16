#!/usr/bin/env bash
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm install \
   cert-manager jetstack/cert-manager \
   --namespace cert-manager \
   --create-namespace \
   --set installCRDs=true
kubectl apply -n cert-manager -f certmgr.yaml 
kubectl apply -n cert-manager -f certmgr-2.yaml
