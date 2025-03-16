#!/usr/bin/env bash
kubectl create namespace startup-reviewboard
kubectl apply -n startup-reviewboard -f .
