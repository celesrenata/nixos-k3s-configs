#!/usr/bin/env bash
helm repo add k8s-at-home https://k8s-at-home.com/charts/
helm repo update
kubectl create namespace sabnzbd-service
helm upgrade -i -f values.sabnzbd sabnzbd k8s-at-home/sabnzbd -n sabnzbd-service 
kubectl apply -n sabnzbd-service -f .
