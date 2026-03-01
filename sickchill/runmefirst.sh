#!/usr/bin/env bash
helm repo add nicholaswilde https://nicholaswilde.github.io/helm-charts/
helm repo update
kubectl create namespace sickchill-service
helm upgrade -i -f values.sickchill sickchill nicholaswilde/sickchill -n sickchill-service 
kubectl apply -n sickchill-service -f .
