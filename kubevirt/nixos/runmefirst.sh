#!/usr/bin/env bash
kubectl create namespace vms
virtctl image-upload --image-path ~/Downloads/nixos-minimal-24.05.5562.1bfbbbe5bbf8-x86_64-linux.iso --size=2Gi pvc nixos-24-05-pvc --access-mode ReadWriteMany --uploadproxy-url https://10.1.1.14:31001 --force-bind --insecure --namespace vms
kubectl apply -f . -n vms 
