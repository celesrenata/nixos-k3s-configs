#!/usr/bin/env bash
kubectl create namespace wordpress-dev
kubectl apply -n wordpress-dev -f .
helm install wordpress-dev oci://registry-1.docker.io/bitnamicharts/wordpress \
	--namespace wordpress-dev \
	--create-namespace \
	--set wordpressUsername=celes \
	--set wordpressPassword=renata \
	--set persistence.enabled=true \
	--set persistence.accessModes[0]=ReadWriteMany \
        --set persistence.existingClaim=wordpress-dev-media-pvc \
	--set ingress.enabled=false \
	--set replicaCount=2 \
	--set mariadb.enabled=false \
	--set externalDatabase.host=10.1.1.2 \
	--set externalDatabase.user=wordpress-dev \
	--set externalDatabase.password=PSCh4ng3me! \
	--set externalDatabase.database=wordpress-dev \
	--set externalDatabase.port=3306 
#	--set livenessProbe.enabled=false \
#	--set readinessProbe.enabled=false
	#--set persistence.size=30Gi \
