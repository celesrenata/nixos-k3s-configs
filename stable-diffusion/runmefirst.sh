#!/usr/bin/env bash
kubectl create namespace stable-diffusion
kubectl apply -f . -n stable-diffusion
