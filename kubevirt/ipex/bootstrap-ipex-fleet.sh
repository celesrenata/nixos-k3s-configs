#!/usr/bin/env bash

# Define Variables

## Hosts defines the ollama-ipex fleet, use the cluster leader as proxy
HOSTS="10.1.1.12:2301,10.1.1.12:2302,10.1.1.12:2303,10.1.1.12:2304,10.1.1.12:2305,10.1.1.12:2306"

## Switches used by PSSH
PSSH_OPTIONS="-h /tmp/resetfleet -t 0 -O StrictHostKeyChecking=no -O ConnectionAttempts=3"

## Commands to iterate with PSSH before reboot
COMMANDS[0]='sudo add-apt-repository ppa:canonical-kernel-team/ppa -y
sudo apt-get update
sudo snap install btop
sudo apt install linux-headers-6.5.0-45-generic linux-image-6.5.0-45-generic linux-modules-extra-6.5.0-45-generic linux-headers-6.5.0-45-generic linux-hwe-6.5-tools-6.5.0-45 -y
echo "options i915 force_probe=7d55 enable_guc=3" | sudo tee -a /etc/modprobe.d/i915.conf
sudo apt install -y linux-firmware
sudo wget https://github.com/intel-gpu/intel-gpu-firmware/raw/main/firmware/mtl_gsc_102.0.0.1511.bin -O /lib/firmware/i915/mtl_gsc_102.0.0.1511.bin
sudo wget https://github.com/intel-gpu/intel-gpu-firmware/raw/main/firmware/mtl_guc_70.6.4.bin -O /lib/firmware/i915/mtl_guc_70.6.4.bin
sudo wget https://github.com/intel-gpu/intel-gpu-firmware/raw/main/firmware/mtl_huc_8.4.3_gsc.bin -O /lib/firmware/i915/mtl_huc_8.4.3_gsc.bin
sudo update-initramfs -u -k all
sudo reboot'

COMMANDS[1]='git clone https://github.com/strongtz/i915-sriov-dkms
sudo apt install build-* dkms -y
cd i915-sriov-dkms && sudo dkms add .
cd i915-sriov-dkms && sudo dkms install -m i915-sriov-dkms -v $(cat VERSION) --force
sudo update-initramfs -u
sudo reboot'

COMMANDS[2]='sudo gpasswd -a ${USER} render
newgrp render
sudo apt-get install -y hwinfo
wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB | gpg --dearmor | sudo tee /usr/share/keyrings/oneapi-archive-keyring.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" | sudo tee /etc/apt/sources.list.d/oneAPI.list
sudo apt update
sudo apt install intel-oneapi-common-vars intel-oneapi-common-oneapi-vars intel-oneapi-diagnostics-utility intel-oneapi-compiler-dpcpp-cpp intel-oneapi-dpcpp-ct intel-oneapi-mkl intel-oneapi-mkl-devel intel-oneapi-mpi intel-oneapi-mpi-devel intel-oneapi-dal intel-oneapi-dal-devel intel-oneapi-ippcp intel-oneapi-ippcp-devel intel-oneapi-ipp intel-oneapi-ipp-devel intel-oneapi-tlt intel-oneapi-ccl intel-oneapi-ccl-devel intel-oneapi-dnnl-devel intel-oneapi-dnnl intel-oneapi-tcm-1.0 -y
wget https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
chmod +x Miniforge3-Linux-x86_64.sh
./Miniforge3-Linux-x86_64.sh -b
yes | miniforge3/bin/conda create -n llm-cpp python=3.11
miniforge3/bin/conda init
sudo reboot'

COMMANDS[3]='source ~/miniforge3/etc/profile.d/conda.sh && conda activate llm-cpp && pip install --pre --upgrade ipex-llm[cpp]
mkdir llama-cpp
cd llama-cpp && init-ollama && init-llama-cpp'

COMMANDS_OLLAMA_SERVE='nohup bash -c "(export no_proxy=localhost,127.0.0.1 && export ZES_ENABLE_SYSMAN=1 && export OLLAMA_NUM_GPU=999 && export OLLAMA_HOST=0.0.0.0 && source /opt/intel/oneapi/setvars.sh --force && export SYCL_CACHE_PERSISTENT=1 && export SYCL_PI_LEVEL_ZERO_USE_IMMEDIATE_COMMANDLISTS=1 && export ONEAPI_DEVICE_SELECTOR=level_zero:0 && ./ollama serve) &> /tmp/ollama.log" &'

COMMANDS_OLLAMA_MODEL='./ollama pull llama2'

# Build Host list
readarray -td, HOST_LIST <<<"$HOSTS"; declare -p HOST_LIST;
printf '%s\n' "${HOST_LIST[@]}" > /tmp/resetfleet
echo
echo "Bootstrap Ollama Fleet:"
printf '%s\n' "${HOST_LIST[@]}"
sleep 10

# Wait for hosts to come online
waitForReboot () {
  while [ "$active" != "true" ]; do
      active=false
      count=0
      for i in $(cat /tmp/resetfleet); do
              sleep 2
              ssh-ping -c 2 -i 5 $(echo "$i" | tr ':' ' -p ') > /dev/null
          if [ $? -eq 0 ]; then
              count=$((count+1))
          fi
          if [ $count -eq 6 ]; then
              active=true
          fi
      done
  done
}

# Run a group of commands
runCommands () {
  readarray -t COMMAND_LIST <<<"$1"; declare -p COMMAND_LIST;
  for cmd in "${COMMAND_LIST[@]}"; do
    echo "Executing: ${cmd}"
    pssh $PSSH_OPTIONS $cmd
    sleep 10
  done
}

# Iterate PSSH Tasks
echo "Installing Kernel, Kernel Modules Intel Dependencies and starting Ollama"
if [ -z "$1" ]; then
  i=0
else
  i=$1
fi
for c in $(seq $i ${#COMMANDS[@]}); do
  waitForReboot
  runCommands "${COMMANDS[$c]}"
done

runCommands "$COMMANDS_OLLAMA_SERVE" &

sleep 20
runCommands "$COMMANDS_OLLAMA_MODEL"

