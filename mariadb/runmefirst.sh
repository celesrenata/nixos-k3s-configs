#!/usr/bin/env bash
kubectl create namespace mariadb-service
helm repo add mariadb-operator https://mariadb-operator.github.io/mariadb-operator
helm install mariadb-operator-crds mariadb-operator/mariadb-operator-crds
helm install mariadb-operator mariadb-operator/mariadb-operator \
	--namespace mariadb-operator \
	--set metrics.enabled=true --create-namespace \
	--set webhook.cert.certManager.enabled=true
kubectl create secret generic mariadb --from-literal=root-password=PSCh4ng3me!
echo "now we wait...60 seconds"
sleep 60 
kubectl apply -n mariadb-service -f .
