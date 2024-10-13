#!/usr/bin/env bash
kubectl create namespace vms
virtctl image-upload --image-path ~/Downloads/Win11_23H2_English_x64v2.iso --size=10Gi pvc win11cd-pvc --access-mode ReadWriteMany --uploadproxy-url https://10.1.1.14:31001 --force-bind --insecure --namespace vms 
virtctl image-upload --image-path ~/Downloads/virtio-win-0.1.262.iso --size=2Gi pvc virtio-drivers-pvc --access-mode ReadWriteMany --uploadproxy-url https://10.1.1.13:31001 --force-bind --insecure --namespace vms 
virtctl image-upload --image-path ~/Downloads/intel_arc.iso --size=2Gi pvc intel-arc-drivers-pvc --access-mode ReadWriteMany --uploadproxy-url https://10.1.1.13:31001 --force-bind --insecure --namespace vms 
kubectl apply -f pvc.yaml -n vms
kubectl apply -f vm.yaml -n vms
kubectl apply -f rdp-service.yaml -n vms
kubectl apply -f service.yaml -n vms
