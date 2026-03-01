#!/usr/bin/env bash
kubectl create namespace postgresql-service
helm repo add cnpg https://cloudnative-pg.github.io/charts
helm install cnpg cnpg/cloudnative-pg \
	--namespace cnpg-system \
	--create-namespace
echo "Waiting for operator to be ready..."
sleep 30
kubectl apply -n postgresql-service -f .

echo "Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=Ready cluster/postgresql -n postgresql-service --timeout=300s

echo "PostgreSQL cluster is ready!"
echo "Connection details:"
echo "Host: 10.1.1.12 (or check 'kubectl get svc postgresql-external -n postgresql-service')"
echo "Port: 5432"
echo "Users: root, celes, jellyfin"
echo "Databases: postgresql, testdb, clusterjellyfin"
echo "Password: PSCh4ng3me!"
