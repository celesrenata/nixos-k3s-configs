#!/usr/bin/env bash
kubectl create namespace vms
fedoraiso='Fedora-Workstation-Live-43-1.6.x86_64.iso'
virtctl image-upload --image-path $fedoraiso --size=3Gi pvc fedora-iso-pvc --access-mode ReadWriteMany --uploadproxy-url https://10.1.1.14:31001 --force-bind --insecure --namespace vms
kubectl apply -f . -n vms 
