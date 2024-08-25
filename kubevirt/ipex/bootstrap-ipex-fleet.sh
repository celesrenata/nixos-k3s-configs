#!/usr/bin/env bash

# This script is used to calibrate the VMs at a greater length than cloud-init can provide sanely
## You can skip to any command group by passing it to the script manually
## Examples:
## ./bootstrap-fleet.sh 0
## This will skip to COMMANDS[0]
## ./bootstrap-fleet.sh 3
## This will skip to COMMANDS[3]

# Define Variables
## Hosts defines the ollama-ipex fleet, use the cluster leader as proxy
## Examples:
## HOSTS="10.1.1.12,10.1.1.13,10.1.1.14"
## HOSTS="10.1.1.12:2031,10.1.1.12:2302,10.1.1.12:2303,10.1.1.12:2304,10.1.1.12:2305,10.1.1.12:2306"
HOSTS="10.1.1.12:2301,10.1.1.12:2302,10.1.1.12:2303,10.1.1.12:2304,10.1.1.12:2305,10.1.1.12:2306"

# Switches used by PSSH
## -h = hostsfile
## -t = timeout
## -0 = ssh passthrough options
## -p = parallelism (3 at a time)
PSSH_OPTIONS="-h /tmp/resetfleet -t 0 -p 3 -O StrictHostKeyChecking=no -O ConnectionAttempts=3"

# Commands to iterate with PSSH
COMMANDS[0]='sudo snap install btop
sudo apt install -y linux-modules-extra-6.8.0-41-generic
echo "options i915 force_probe=7d55 enable_guc=3" | sudo tee -a /etc/modprobe.d/i915.conf
sudo mkdir -p /lib/firmware/i915
sudo wget https://github.com/intel-gpu/intel-gpu-firmware/raw/main/firmware/mtl_gsc_102.0.0.1511.bin -O /lib/firmware/i915/mtl_gsc_102.0.0.1511.bin
sudo wget https://github.com/intel-gpu/intel-gpu-firmware/raw/main/firmware/mtl_guc_70.6.4.bin -O /lib/firmware/i915/mtl_guc_70.6.4.bin
sudo wget https://github.com/intel-gpu/intel-gpu-firmware/raw/main/firmware/mtl_huc_8.4.3_gsc.bin -O /lib/firmware/i915/mtl_huc_8.4.3_gsc.bin
git clone https://github.com/strongtz/i915-sriov-dkms
sudo apt install build-* dkms -y
cd i915-sriov-dkms && sudo dkms add .
cd i915-sriov-dkms && sudo dkms install -m i915-sriov-dkms -v $(cat VERSION) --force
sudo update-initramfs -u
sudo shutdown -r now &'

COMMANDS[1]='sudo gpasswd -a ${USER} render
newgrp render
wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB | gpg --dearmor | sudo tee /usr/share/keyrings/oneapi-archive-keyring.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" | sudo tee /etc/apt/sources.list.d/oneAPI.list
wget -qO - https://repositories.intel.com/gpu/intel-graphics.key | sudo gpg --yes --dearmor --output /usr/share/keyrings/intel-graphics.gpg
echo "deb [arch=amd64,i386 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu jammy client" | sudo tee /etc/apt/sources.list.d/intel-gpu-jammy.list
sudo apt update
sudo apt install -y intel-opencl-icd intel-level-zero-gpu level-zero intel-level-zero-gpu-raytracing intel-media-va-driver-non-free libmfx1 libmfxgen1 libvpl2 libegl-mesa0 libegl1-mesa libegl1-mesa-dev libgbm1 libgl1-mesa-dev libgl1-mesa-dri libglapi-mesa libgles2-mesa-dev libglx-mesa0 libigdgmm12 libxatracker2 mesa-va-drivers mesa-vdpau-drivers mesa-vulkan-drivers va-driver-all vainfo hwinfo clinfo'

COMMANDS[2]='sudo apt install intel-oneapi-common-vars intel-oneapi-common-oneapi-vars intel-oneapi-diagnostics-utility intel-oneapi-compiler-dpcpp-cpp intel-oneapi-dpcpp-ct intel-oneapi-mkl intel-oneapi-mkl-devel intel-oneapi-mpi intel-oneapi-mpi-devel intel-oneapi-dal intel-oneapi-dal-devel intel-oneapi-ippcp intel-oneapi-ippcp-devel intel-oneapi-ipp intel-oneapi-ipp-devel intel-oneapi-tlt intel-oneapi-ccl intel-oneapi-ccl-devel intel-oneapi-dnnl-devel intel-oneapi-dnnl intel-oneapi-tcm-1.0 -y
sudo apt install -y intel-basekit
wget https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
chmod +x Miniforge3-Linux-x86_64.sh
./Miniforge3-Linux-x86_64.sh -b
yes | miniforge3/bin/conda create -n llm-cpp python=3.11
miniforge3/bin/conda init
sudo shutdown -r now &'

COMMANDS[3]='source ~/miniforge3/etc/profile.d/conda.sh && conda activate llm-cpp && pip install --pre --upgrade ipex-llm[cpp] && pip install transformers && pip install trl
mkdir llama-cpp -p
source ~/miniforge3/etc/profile.d/conda.sh && conda activate llm-cpp && cd llama-cpp && init-ollama && init-llama-cpp'

COMMANDS[4]='source ~/miniforge3/etc/profile.d/conda.sh && conda activate llm-cpp && yes | pip install --pre --upgrade ipex-llm[xpu] --extra-index-url https://pytorch-extension.intel.com/release-whl/stable/xpu/us/
source ~/miniforge3/etc/profile.d/conda.sh && conda activate llm-cpp && yes | pip install --pre --upgrade ipex-llm[cpp] && pip install transformers && pip install trl
source ~/miniforge3/etc/profile.d/conda.sh && conda activate llm-cpp
wget https://raw.githubusercontent.com/intel-analytics/ipex-llm/main/python/llm/example/GPU/HuggingFace/LLM/llama3.1/generate.py
cd llama-cpp && wget https://huggingface.co/lmstudio-community/Meta-Llama-3-8B-Instruct-GGUF/resolve/main/Meta-Llama-3-8B-Instruct-Q4_K_M.gguf'

COMMANDS[5]='source ~/miniforge3/etc/profile.d/conda.sh && conda activate llm-cpp && source /opt/intel/oneapi/setvars.sh && cd llama-cpp && ZES_ENABLE_SYSMAN=1 ./main -m Meta-Llama-3-8B-Instruct-Q4_K_M.gguf -n 32 --prompt "Once upon a time, there existed a little girl who liked to have adventures. She wanted to go to places and meet new people, and have fun doing something" -t 8 -e -ngl 33 --color --no-mmap > /tmp/llama.cpp'

# Build Host list
readarray -td, HOST_LIST <<<"$HOSTS"; declare -p HOST_LIST;
printf '%s\n' "${HOST_LIST[@]}" > /tmp/resetfleet
echo
echo "Bootstrap Ollama Fleet:"
printf '%s\n' "${HOST_LIST[@]}"

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

# Detect if user wants to fastforward commands
if [ -z "$1" ]; then
  i=0
else
  i=$1
fi

# Iterate PSSH Tasks
echo "Installing Kernel, Kernel Modules Intel Dependencies and starting Ollama"
for c in $(seq $i $(expr ${#COMMANDS[@]} - 1)); do
  waitForReboot
  sleep 10
  runCommands "${COMMANDS[$c]}"
  sleep 30
done
