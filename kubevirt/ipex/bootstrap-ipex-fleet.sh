#!/usr/bin/env bash

# Define Variables

## Hosts defines the ollama-ipex fleet, use the cluster leader as proxy
HOSTS="10.1.1.12:2301,10.1.1.12:2302,10.1.1.12:2303,10.1.1.12:2304,10.1.1.12:2305,10.1.1.12:2306"

## Switches used by PSSH
PSSH_OPTIONS="-h /tmp/resetfleet -t 0 -O StrictHostKeyChecking=no -O ConnectionAttempts=3"

## Commands to iterate with PSSH before reboot
COMMANDS='wget -qO - https://repositories.intel.com/gpu/intel-graphics.key | sudo gpg --yes --dearmor --output /usr/share/keyrings/intel-graphics.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu jammy/lts/2350 unified" | sudo tee /etc/apt/sources.list.d/intel-gpu-jammy.list
wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB | gpg --dearmor | sudo tee /usr/share/keyrings/oneapi-archive-keyring.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" | sudo tee /etc/apt/sources.list.d/oneAPI.list
sudo apt update --allow-insecure-repositories
sudo apt install -y intel-opencl-icd intel-level-zero-gpu level-zero intel-media-va-driver-non-free libmfx1 libmfxgen1 libvpl2 libegl-mesa0 libegl1-mesa libegl1-mesa-dev libgbm1 libgl1-mesa-dev libgl1-mesa-dri libglapi-mesa libgles2-mesa-dev libglx-mesa0 libigdgmm12 libxatracker2 mesa-va-drivers mesa-vdpau-drivers mesa-vulkan-drivers va-driver-all vainfo hwinfo clinfo
sudo apt install -y libigc-dev intel-igc-cm libigdfcl-dev libigfxcmrt-dev level-zero-dev
sudo apt install -y intel-basekit intel-renderkit
sudo gpasswd -a ${USER} render
sudo reboot'
COMMANDS2='curl -fsSL https://ollama.com/install.sh | sh
sudo systemctl stop ollama
wget https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
chmod +x Miniforge3-Linux-x86_64.sh
./Miniforge3-Linux-x86_64.sh -b
yes | miniforge3/bin/conda create -n llm-cpp python=3.11
miniforge3/bin/conda init
source ~/miniforge3/etc/profile.d/conda.sh && conda activate llm-cpp && pip install --pre --upgrade ipex-llm[cpp]
nohup bash -c "(export no_proxy=localhost,127.0.0.1 && export ZES_ENABLE_SYSMAN=1 && export OLLAMA_NUM_GPU=999 && export OLLAMA_HOST=0.0.0.0 && source /opt/intel/oneapi/setvars.sh --force && export SYCL_CACHE_PERSISTENT=1 && export SYCL_PI_LEVEL_ZERO_USE_IMMEDIATE_COMMANDLISTS=1 && export ONEAPI_DEVICE_SELECTOR=level_zero:0 && ollama serve) &> /tmp/ollama.log" &
sleep 10
ollama pull llama3.1'

# Build Host list
readarray -td, HOST_LIST <<<"$HOSTS"; declare -p HOST_LIST;
printf '%s\n' "${HOST_LIST[@]}" > /tmp/resetfleet
echo
echo "Bootstrap Ollama Fleet:"
printf '%s\n' "${HOST_LIST[@]}"
sleep 10

# Wait for hosts to come online
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

# Build Command list
readarray -t COMMAND_LIST <<<"$COMMANDS"; declare -p COMMAND_LIST;

# Iterate PSSH Tasks
echo "Installing dependencies and starting Ollama"

for cmd in "${COMMAND_LIST[@]}"; do
    echo "Executing: ${cmd}"
    pssh $PSSH_OPTIONS $cmd
    sleep 10
done
sleep 30

# Wait for hosts to reboot
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
sleep 10

# Build Command2 list
readarray -t COMMAND_LIST2 <<<"$COMMANDS2"; declare -p COMMAND_LIST2;

# Iterate PSSH Tasks
echo "Installing dependencies and starting Ollama"

for cmd in "${COMMAND_LIST2[@]}"; do
    echo "Executing: ${cmd}"
    pssh $PSSH_OPTIONS $cmd
    sleep 10
done
