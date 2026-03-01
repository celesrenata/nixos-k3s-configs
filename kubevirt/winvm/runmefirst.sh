#!/usr/bin/env bash
kubectl port-forward -n cdi service/cdi-uploadproxy 8444:443 &
timeout 300 kubectl create namespace vms
virtctl image-upload --image-path ~/Downloads/Win11_23H2_English_x64v2.iso --size=7Gi pvc win11cd-pvc --access-mode ReadWriteMany --uploadproxy-url https://127.0.0.1:8444 --force-bind --insecure --namespace vms 
timeout 300 virtctl image-upload --image-path ~/Downloads/virtio-win-0.1.262.iso --size=7Gi pvc virtio-drivers-pvc --access-mode ReadWriteMany --uploadproxy-url https://127.0.0.1:8444 --force-bind --insecure --namespace vms 
timeout 300 virtctl image-upload --image-path ~/Downloads/intel_arc.iso --size=1Gi pvc intel-arc-drivers-pvc --access-mode ReadWriteMany --uploadproxy-url https://127.0.0.1:8444 --force-bind --insecure --namespace vms 
kubectl apply -f pvc.yaml -n vms
kubectl apply -f vm.yaml -n vms
kubectl apply -f rdp-service.yaml -n vms
