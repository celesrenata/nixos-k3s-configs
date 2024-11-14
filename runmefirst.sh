#!/usr/bin/env bash

# Kubernetes Projects to Activate
PROJECTS='dashboard
longhorn
traefik
prometheus
influxdb2
cert-manager
intel
nvidia
grafana
phpmyadmin
portainer
homeassistant
mariadb
flame
hastebin
ollama
open-webui
comfyui
OneTrainer
wordpress
unifi
kubevirt
clusterplex
kubevirt/winvm-nfs
kubevirt/al2023
kubevirt/arch
kubevirt/nixos'

#intel
# Build Project List
readarray -t PROJECT_LIST <<<"$PROJECTS"; declare -p PROJECT_LIST;
CWD=$(pwd)
# Run fleet install
for cmd in "${PROJECT_LIST[@]}"; do
    echo -e "\e[32m##################\e[0m"
    echo -e "\e[32mInstalling: ${cmd}\e[0m"
    echo -e "\e[32m##################\e[0m"
    cd ${cmd}
    ./runmefirst.sh
    cd ${CWD}
    sleep 20
done
