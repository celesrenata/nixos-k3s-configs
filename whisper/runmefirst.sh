#!/usr/bin/env bash
kubectl create namespace whisper-service
kubectl apply -f . -n whisper-service
