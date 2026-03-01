#!/usr/bin/env bash
kubectl -n wordpress-dev exec $(kubectl -n wordpress-dev get pods -l app.kubernetes.io/name=wordpress -o jsonpath='{.items[0].metadata.name}') -c wordpress -- wp maintenance-mode deactivate 
kubectl -n wordpress-dev exec $(kubectl -n wordpress-dev get pods -l app.kubernetes.io/name=wordpress -o jsonpath='{.items[1].metadata.name}') -c wordpress -- wp maintenance-mode deactivate
