#!/usr/bin/env bash
helm repo add mongodb https://mongodb.github.io/helm-charts
helm upgrade -i mongodb-operator mongodb/community-operator \
	--namespace mongodb-operator --create-namespace \
	--set operator.watchNamespace="*"

#kubectl create namespace rainbow-mongodb
#kubectl apply -f rainbow-mongodb.yaml -n rainbow-mongodb
#helm install mongodb bitnami/mongodb \
#	--namespace rainbow-mongodb \
#	--set persistence.existingClaim=rainbow-mongodb-pvc
