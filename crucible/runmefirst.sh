#!/usr/bin/env bash
helm repo add postgres-operator-charts https://opensource.zalando.com/postgres-operator/charts/postgres-operator
helm install --namespace postgres-operator --create-namespace postgres-operator postgres-operator-charts/postgres-operator
#helm repo add postgres-operator-ui-charts https://opensource.zalando.com/postgres-operator/charts/postgres-operator-ui
#helm install postgres-operator-ui postgres-operator-ui-charts/postgres-operator-ui
echo "now we wait 60"
sleep 60
kubectl create namespace docker-crucible
kubectl apply -n docker-crucible -f .
