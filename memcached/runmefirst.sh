#!/usr/bin/env bash
helm install memcached-service --namespace docker-reviewboard --create-namespace oci://registry-1.docker.io/bitnamicharts/memcached
kubectl apply -n docker-reviewboard -f .
