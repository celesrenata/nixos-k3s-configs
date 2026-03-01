helm repo add intel https://intel.github.io/helm-charts/
helm repo add jetstack https://charts.jetstack.io # for cert-manager
helm repo add nfd https://kubernetes-sigs.github.io/node-feature-discovery/charts
helm repo update
helm install nfd nfd/node-feature-discovery \
  --namespace node-feature-discovery --create-namespace
kubectl create namespace intel-system
echo "Now we wait 30"
sleep 30
helm install device-plugin-operator intel/intel-device-plugins-operator --namespace intel-system
echo "Now we wait 30"
sleep 30
helm install gpu intel/intel-device-plugins-gpu --namespace intel-system \
  --set nodeFeatureRule=true \
  --set sharedDevNum=1 \
  --set resourceManager=true
kubectl label nodes gremlin-1 gremlin-2 gremlin-3 gremlin-4 intel.feature.node.kubernetes.io/gpu=true
