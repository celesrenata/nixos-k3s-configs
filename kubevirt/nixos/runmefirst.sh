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

# Upload image using localhost port-forward
virtctl image-upload --image-path ~/Downloads/nixos-minimal-24.05.5562.1bfbbbe5bbf8-x86_64-linux.iso --size=2Gi pvc nixos-24-05-pvc --access-mode ReadWriteMany --uploadproxy-url https://localhost:18443 --force-bind --insecure --namespace vms

# Apply remaining resources
kubectl apply -f . -n vms 
