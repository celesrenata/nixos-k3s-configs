#!/usr/bin/env bash
kubectl create namespace wordpress
kubectl apply -n wordpress -f ingress.yaml
helm install wordpress oci://registry-1.docker.io/bitnamicharts/wordpress \
	--namespace wordpress \
	--create-namespace \
	--set wordpressUsername=celes \
	--set wordpressPassword=renata \
	--set persistence.enabled=true \
	--set persistence.size=40Gi \
	--set ingress.enabled=false \
	--set replicaCount=1 \
	--set livenessProbe.failureThreshold=60 \
	--set readinessProbe.failureThreshold=60 \
	--set startupProbe.failureThreshold=60 \
	--set mariadb.enabled=false \
	--set externalDatabase.host=10.1.1.12 \
	--set externalDatabase.user=wordpress-dev \
	--set externalDatabase.password=PSCh4ng3me! \
	--set externalDatabase.database=wordpress-dev \
        --set externalDatabase.port=3306 
#	--set persistence.existingClaim=wordpress-dev-media-pvc \
#	--set persistence.accessModes[0]=ReadWriteMany \
#	--set livenessProbe.enabled=false \
#	--set readinessProbe.enabled=false
