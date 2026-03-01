#!/usr/bin/env bash
helm repo add influxdata https://helm.influxdata.com/
helm upgrade --install influxdb influxdata/influxdb2 -f values.yaml \
       	--namespace influxdb-service \
       	--create-namespace
kubectl apply -f . -n influxdb-service
