#!/usr/bin/env bash
krew install virt
export VERSION=$(curl -s https://storage.googleapis.com/kubevirt-prow/release/kubevirt/kubevirt/stable.txt)
#VERSION="v1.2.2"
echo $VERSION
kubectl create -f https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/kubevirt-operator.yaml 
kubectl create -f https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/kubevirt-cr.yaml
#export VERSION=$(basename $(curl -s -w %{redirect_url} https://github.com/kubevirt/containerized-data-importer/releases/latest))
VERSION="v1.59.1"
kubectl create -f https://github.com/kubevirt/containerized-data-importer/releases/download/$VERSION/cdi-operator.yaml
kubectl create -f https://github.com/kubevirt/containerized-data-importer/releases/download/$VERSION/cdi-cr.yaml
kubectl apply -f https://raw.githubusercontent.com/kubevirt-manager/kubevirt-manager/main/kubernetes/bundled.yaml -n kubevirt-manager
kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset-thick.yml
kubectl apply -f cdi-quota.yaml -n cdi
kubectl apply -f cdi-config.yaml -n cdi
kubectl apply -f kubevirt-service.yaml -n cdi 
kubectl create namespace vmimages
kubectl create namespace vms
kubectl apply -f kubevirt-intel.yaml -n kubevirt
kubectl apply -f fsGroupPolicy.yaml -n cdi 
#kubectl patch kubevirt kubevirt -n kubevirt --patch "$(cat kubevirt-patch.yaml)" --type=merge
#kubectl create -f dv_ubuntu.yaml -n vmimages
