#!/usr/bin/env bash
cwd=$(pwd)
cd k8s-gerrit
cd $(git rev-parse --show-toplevel)/helm-charts
helm install --namespace gerritcr-service --create-namespace \
  gerrit \
  ./gerrit \
  --set=gitRepositoryStorage.size=10Gi \
  --set=nfsWorkaround.enabled=true \
  --set=nfsWorkaround.idDomain=celestium.life \
  --set=gitRepositoryStorage.externalPVC.use=true \
  --set=gitRepositoryStorage.externalPVC.name=git-repositories-pvc \
  --set=logStorage.externalPVC.use=true \
  --set=logStorage.externalPVC.name=gerrit-logs-pvc \
  --set=storageClasses.default.name=longhorn \
  --set=images.registry.ImagePullSecret.create=true 
cd $cwd
kubectl apply -n gerritcr-service -f .
