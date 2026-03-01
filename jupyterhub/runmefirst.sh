#!/usr/bin/env bash
helm repo add jupyterhub https://hub.jupyter.org/helm-chart/
helm repo update

helm upgrade --cleanup-on-fail \
	--install jupyterhub jupyterhub/jupyterhub \
	--namespace jupyterhub-service \
	--create-namespace \
	--version 4.3.2 \
	--values config.yaml \
	--values gpu-values.yaml
kubectl apply -f ingress.yaml -n jupyterhub-service
kubectl apply -f nfs-pv.yaml -n jupyterhub-service
kubectl apply -f nfs-pvc.yaml -n jupyterhub-service
