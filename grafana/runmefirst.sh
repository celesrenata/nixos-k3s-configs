#!/usr/bin/env bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
helm install grafana grafana/grafana -n grafana-service --create-namespace \
	--set persistence.enabled=true \
	--set persistence.existingClaim=grafana-pvc
kubectl apply -f . -n grafana-service
sleep 10
echo -en "\e[31m"
kubectl get secret --namespace grafana-service grafana -o jsonpath="{.data.admin-password}" | base64 --decode > grafana-admin-pass; echo -en "\e[31m" $(cat grafana-admin-pass) "\e[0m"
echo ""
