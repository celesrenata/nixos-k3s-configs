#!/usr/bin/env bash

# Create namespace
kubectl create namespace vms

# Start port-forward to CDI upload proxy in background
echo "Setting up port-forward to CDI upload proxy..."
kubectl port-forward -n cdi svc/cdi-uploadproxy 18443:443 &
PF_PID=$!

# Wait a moment for port-forward to establish
sleep 3

# Function to cleanup port-forward on exit
cleanup() {
    echo "Cleaning up port-forward..."
    kill $PF_PID 2>/dev/null
}
trap cleanup EXIT

# Upload images using localhost port-forward
virtctl image-upload --image-path ~/Downloads/Win11_24H2_English_x64.iso --size=10Gi pvc win11cd-pvc --access-mode ReadWriteMany --uploadproxy-url https://localhost:18443 --force-bind --insecure --namespace vms 
virtctl image-upload --image-path ~/Downloads/virtio-win-0.1.262.iso --size=2Gi pvc virtio-drivers-pvc --access-mode ReadWriteMany --uploadproxy-url https://localhost:18443 --force-bind --insecure --namespace vms 
virtctl image-upload --image-path ~/Downloads/intel_arc.iso --size=2Gi pvc intel-arc-drivers-pvc --access-mode ReadWriteMany --uploadproxy-url https://localhost:18443 --force-bind --insecure --namespace vms 
kubectl apply -f configmap-with-rom.yaml -n vms
kubectl apply -f nfs-pv.yaml -n vms
kubectl apply -f nfs-pvc.yaml -n vms
kubectl apply -f pv.yaml -n vms
kubectl apply -f pvc.yaml -n vms
kubectl apply -f vm-with-rom.yaml -n vms
kubectl apply -f rdp-service.yaml -n vms
kubectl apply -f service.yaml -n vms
