helm repo add intel https://intel.github.io/helm-charts/
helm repo add jetstack https://charts.jetstack.io # for cert-manager
helm repo add nfd https://kubernetes-sigs.github.io/node-feature-discovery/charts
helm repo update
helm install nfd nfd/node-feature-discovery \
  --namespace node-feature-discovery --create-namespace
kubectl create namespace intel-system
sleep 10
helm install device-plugin-operator intel/intel-device-plugins-operator -n intel-system
sleep 10
helm install gpu intel/intel-device-plugins-gpu --namespace intel-system \
  --set nodeFeatureRule=true
