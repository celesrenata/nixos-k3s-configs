#!/usr/bin/env bash

# Define Variables

## Hosts defines the kube cluster, use the cluster leader as first hots
#HOSTS="gremlin-1,gremlin-2,gremlin-3"
HOSTS="10.1.1.12,10.1.1.13,10.1.1.14"

## Switches used by PSSH
PSSH_OPTIONS="--user root -h /tmp/resetfleet -t 0 -O StrictHostKeyChecking=no -O ConnectionAttempts=3"

## Commands to iterate with PSSH before reboot
COMMANDS='cp /etc/nixos/configuration.nix /etc/nixos/configuration.nix.bak
cp /etc/nixos/configuration.nix.reset /etc/nixos/configuration.nix
nixos-rebuild switch
export KUBELET_PATH=$(mount | grep kubelet | cut -d " " -f3); ${KUBELET_PATH:+umount $KUBELET_PATH}; while [ $? -ne 0 ]; do ${KUBELET_PATH:+umount $KUBELET_PATH}; sleep 10; done
rm -rf /etc/rancher/{k3s,node};while [ $? -ne 0 ]; do rm -rf /etc/rancher/{k3s,node}; sleep 10; done
rm -rf /var/lib/{rancher/k3s,kubelet,longhorn,etcd,cni}; while [ $? -ne 0 ]; do rm -rf /var/lib/{rancher/k3s,kubelet,longhorn,etcd,cni}; sleep 10; done
rm -rf /var/lib/etcd/; while [ $? -ne 0 ]; do rm rm -rf /var/lib/etcd/; sleep 10; done
reboot'

# Build Host list
readarray -td, HOST_LIST <<<"$HOSTS"; declare -p HOST_LIST;
printf '%s\n' "${HOST_LIST[@]}" > /tmp/resetfleet
echo
echo "these Hosts kubernetes configurations will be nuked by this change:"
printf '%s\n' "${HOST_LIST[@]}"
sleep 10

# Build Command list
readarray -t COMMAND_LIST <<<"$COMMANDS"; declare -p COMMAND_LIST;

# Iterate PSSH Tasks
echo "nuking fleet"

for cmd in "${COMMAND_LIST[@]}"; do
    echo "Executing: ${cmd}"
    pssh $PSSH_OPTIONS $cmd
    sleep 10
done

sleep 60
# Wait for hosts to reboot
while [ "$active" != "true" ]; do
    active=false
    count=0
    for i in $(cat /tmp/resetfleet); do
        ssh-ping -c 3 -i 5 $i > /dev/null
	if [ $? -eq 0 ]; then
	    count=$((count+1))
	fi
	if [ $count -eq 3 ]; then
	    active=true
	fi
    done
done
sleep 10

# Re-enable Kube
echo "Executing: cp /etc/nixos/configuration.nix.bak /etc/nixos/configuration.nix"
pssh $PSSH_OPTIONS 'cp /etc/nixos/configuration.nix.bak /etc/nixos/configuration.nix'
sleep 1
echo "Executing: nixos-rebuild switch"
pssh $PSSH_OPTIONS -p 1 'nixos-rebuild switch'
echo ${HOST_LIST[0]} > /tmp/resetfleet1
sleep 10

# Copy Config
echo "Executing: cat /etc/rancher/k3s/k3s.yaml"
pssh -i --user root -h /tmp/resetfleet1 -t 0 -O StrictHostKeyChecking=no 'cat /etc/rancher/k3s/k3s.yaml' | sed "s/127\.0\.0\.1/$(cat /tmp/resetfleet1)/g" | sed '1d' | sed '/^Stderr/d' > ~/.kube/config
echo "config written!"
