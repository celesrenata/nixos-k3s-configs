#!/usr/bin/env bash
kubectl create namespace docker-reviewboard
kubectl apply -n docker-reviewboard -f .
