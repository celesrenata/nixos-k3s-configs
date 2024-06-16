#!/usr/bin/env bash
helm install phpmyadmin oci://registry-1.docker.io/bitnamicharts/phpmyadmin --namespace phpmyadmin-service --create-namespace
kubectl apply -n phpmyadmin-service -f phpmyadmin-ingress.yaml
