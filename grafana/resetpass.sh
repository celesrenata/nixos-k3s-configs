#!/usr/bin/env bash
echo -en "\e[31mEnter new granafa password: \e[31m"
read -s grafanapass
kubectl exec --namespace grafana-service -it $(kubectl get pods --namespace grafana-service -l "app.kubernetes.io/name=grafana" -o jsonpath="{.items[0].metadata.name}") -- grafana cli admin reset-admin-password ${grafanapass}
