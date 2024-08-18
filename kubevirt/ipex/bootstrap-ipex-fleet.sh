#!/usr/bin/env bash

# Define Variables

## Hosts defines the ollama-ipex fleet, use the cluster leader as proxy
HOSTS="10.1.1.12:2301,10.1.1.12:2302,10.1.1.12:2303,10.1.1.12:2304,10.1.1.12:2305,10.1.1.12:2306"

## Switches used by PSSH
PSSH_OPTIONS="-h /tmp/resetfleet -t 0 -O StrictHostKeyChecking=no -O ConnectionAttempts=3"

## Commands to iterate with PSSH before reboot
COMMANDS='wget -qO - https://repositories.intel.com/gpu/intel-graphics.key | sudo gpg --yes --dearmor --output /usr/share/keyrings/intel-graphics.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu jammy/lts/2350 unified" | sudo tee /etc/apt/sources.list.d/intel-gpu-jammy.list
sudo apt update
sudo apt install -y intel-opencl-icd intel-level-zero-gpu level-zero intel-media-va-driver-non-free libmfx1 libmfxgen1 libvpl2 libegl-mesa0 libegl1-mesa libegl1-mesa-dev libgbm1 libgl1-mesa-dev libgl1-mesa-dri libglapi-mesa libgles2-mesa-dev libglx-mesa0 libigdgmm12 libxatracker2 mesa-va-drivers mesa-vdpau-drivers mesa-vulkan-drivers va-driver-all vainfo hwinfo clinfo
sudo apt install -y libigc-dev intel-igc-cm libigdfcl-dev libigfxcmrt-dev level-zero-dev
sudo gpasswd -a ${USER} render
sudo reboot'
COMMANDS2='wget https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
chmod +x Miniforge3-Linux-x86_64.sh
./Miniforge3-Linux-x86_64.sh -b
yes | miniforge3/bin/conda create -n llm python=3.11 libuv
miniforge3/bin/conda init
conda activate llm && pip install --pre --upgrade ipex-llm[xpu] --extra-index-url https://pytorch-extension.intel.com/release-whl/stable/xpu/us/
source /opt/intel/oneapi/setvars.sh && export SYCL_CACHE_PERSISTENT=1 && export SYCL_PI_LEVEL_ZERO_USE_IMMEDIATE_COMMANDLISTS=1 && export ONEAPI_DEVICE_SELECTOR=level_zero:0 && nohup ./main -m <model_dir>/Meta-Llama-3-8B-Instruct-Q4_K_M.gguf -n 32 --prompt "Once upon a time, there existed a little girl who liked to have adventures. She wanted to go to places and meet new people, and have fun doing something" -t 8 -e -ngl 33 --color --no-mmap'

# Build Host list
readarray -td, HOST_LIST <<<"$HOSTS"; declare -p HOST_LIST;
printf '%s\n' "${HOST_LIST[@]}" > /tmp/resetfleet
echo
echo "Bootstrap Ollama Fleet:"
printf '%s\n' "${HOST_LIST[@]}"
sleep 10

# Build Command list
readarray -t COMMAND_LIST <<<"$COMMANDS"; declare -p COMMAND_LIST;

# Iterate PSSH Tasks
echo "Installing dependencies and starting Ollama"

for cmd in "${COMMAND_LIST[@]}"; do
    echo "Executing: ${cmd}"
    pssh $PSSH_OPTIONS $cmd
    sleep 10
done

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
