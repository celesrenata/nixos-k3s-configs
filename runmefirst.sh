#!/usr/bin/env bash

# Kubernetes Projects to Activate
PROJECTS='dashboard
kyverno
longhorn
traefik
cert-manager
grafana
phpmyadmin
prometheus
intel
homeassistant
mariadb
flame
wordpress
unifi
kubevirt
clusterplex
sleep
sleep
kubevirt/al2023
kubevirt/arch
kubevirt/ipex'

#intel
# Build Project List
readarray -t PROJECT_LIST <<<"$PROJECTS"; declare -p PROJECT_LIST;

# Run fleet install
for cmd in "${PROJECT_LIST[@]}"; do
    echo -e "\e[32m##################\e[0m"
    echo -e "\e[32mInstalling: ${cmd}\e[0m"
    echo -e "\e[32m##################\e[0m"
    cd ${cmd}
    ./runmefirst.sh
    cd ..
    sleep 10
done
