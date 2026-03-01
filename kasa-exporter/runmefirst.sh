#!/usr/bin/env bash
kubectl create namespace docker-kasa-exporter
kubectl apply -n docker-kasa-exporter -f .
