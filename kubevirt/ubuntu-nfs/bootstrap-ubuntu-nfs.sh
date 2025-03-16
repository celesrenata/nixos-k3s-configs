#!/usr/bin/env bash
# Define Variables

## Hosts defines the ollama-ipex fleet, use the cluster leader as proxy
HOSTS="10.1.1.12:2901"

## Switches used by PSSH
PSSH_OPTIONS="-h /tmp/resetfleet -p 1 -t 0 -O StrictHostKeyChecking=no -O ConnectionAttempts=3"

# Copy xorg.conf needed by XRDP for Intel acceleration.
scp -P 2901 xorg.conf 10.1.1.12:
scp -P 2901 0build-xrdp-glamor-annotated.sh 10.1.1.12:

## Commands to iterate with PSSH before reboot
read -r -d '' COMMANDS[0] << EEOF
sudo apt update
sudo apt install -y prometheus-node-exporter
sudo snap install btop
sudo apt install -y linux-headers-6.8.0-41-generic linux-headers-6.8.0-41 linux-image-6.8.0-41-generic linux-modules-6.8.0-41-generic linux-tools-6.8.0-41-generic linux-modules-extra-6.8.0-41-generic 
sudo apt-mark hold linux-headers-6.8.0-41-generic linux-headers-6.8.0-41 linux-image-6.8.0-41-generic linux-modules-6.8.0-41-generic linux-tools-6.8.0-41-generic linux-modules-extra-6.8.0-41-generic 
sudo mv /usr/bin/linux-check-removal /usr/bin/linux-check-removal.orig
echo -e '#!/bin/sh\necho "Overriding default linux-check-removal script!"\nexit 0' | sudo tee /usr/bin/linux-check-removal
sudo chmod +x /usr/bin/linux-check-removal
sudo apt remove -y linux-headers-\$(uname -r) linux-image-\$(uname -r) linux-modules-\$(uname -r) linux-tools-\$(uname -r) linux-modules-extra-\$(uname -r)
echo "options i915 force_probe=7d55 enable_guc=3" | sudo tee -a /etc/modprobe.d/i915.conf
sudo apt -y upgrade
echo "blacklist xe" | sudo tee -a /etc/modprobe.d/blacklist.conf
sudo mkdir -p /lib/firmware/i915
sudo wget https://github.com/intel-gpu/intel-gpu-firmware/raw/main/firmware/mtl_gsc_102.0.0.1511.bin -O /lib/firmware/i915/mtl_gsc_102.0.0.1511.bin
sudo wget https://github.com/intel-gpu/intel-gpu-firmware/raw/main/firmware/mtl_guc_70.6.4.bin -O /lib/firmware/i915/mtl_guc_70.6.4.bin
sudo wget https://github.com/intel-gpu/intel-gpu-firmware/raw/main/firmware/mtl_huc_8.4.3_gsc.bin -O /lib/firmware/i915/mtl_huc_8.4.3_gsc.bin
sudo shutdown -r now &
EEOF

COMMANDS[1]='git clone https://github.com/strongtz/i915-sriov-dkms
cd i915-sriov-dkms && git checkout e26ce8952e465762fc0743731aa377ec0b2889ff
sudo apt install build-* dkms -y
cd i915-sriov-dkms && sudo dkms add .
cd i915-sriov-dkms && sudo dkms install -m i915-sriov-dkms -v $(cat VERSION) --force
sudo update-initramfs -u
sudo shutdown -r now &'

COMMANDS[2]='sudo gpasswd -a ${USER} render
newgrp render
wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB | gpg --dearmor | sudo tee /usr/share/keyrings/oneapi-archive-keyring.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" | sudo tee /etc/apt/sources.list.d/oneAPI.list
wget -qO - https://repositories.intel.com/gpu/intel-graphics.key | sudo gpg --yes --dearmor --output /usr/share/keyrings/intel-graphics.gpg
echo "deb [arch=amd64,i386 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/gpu/ubuntu jammy client" | sudo tee /etc/apt/sources.list.d/intel-gpu-jammy.list
sudo add-apt-repository -y ppa:kisak/kisak-mesa
sudo apt update
sudo apt install -y intel-opencl-icd intel-level-zero-gpu level-zero intel-level-zero-gpu-raytracing intel-media-va-driver-non-free libmfx1 libmfxgen1 libvpl2 libegl-mesa0 libegl1-mesa libegl1-mesa-dev libgbm1 libgl1-mesa-dev libgl1-mesa-dri libglapi-mesa libgles2-mesa-dev libglx-mesa0 libigdgmm12 libxatracker2 mesa-va-drivers mesa-vdpau-drivers mesa-vulkan-drivers va-driver-all vainfo hwinfo clinfo autoconf libtool pkg-config libfuse3-dev'

COMMANDS[3]='sudo apt install intel-oneapi-common-vars intel-oneapi-common-oneapi-vars intel-oneapi-diagnostics-utility intel-oneapi-compiler-dpcpp-cpp intel-oneapi-dpcpp-ct intel-oneapi-mkl intel-oneapi-mkl-devel intel-oneapi-mpi intel-oneapi-mpi-devel intel-oneapi-dal intel-oneapi-dal-devel intel-oneapi-ippcp intel-oneapi-ippcp-devel intel-oneapi-ipp intel-oneapi-ipp-devel intel-oneapi-tlt intel-oneapi-ccl intel-oneapi-ccl-devel intel-oneapi-dnnl-devel intel-oneapi-dnnl intel-oneapi-tcm-1.0 -y
sudo apt install -y intel-basekit xfce4
sudo apt update
sudo mkdir -p /etc/X11/xrdp
sudo cp xorg.conf /etc/X11/xrdp
sudo usermod -a -G video $USER && sudo usermod -a -G render $USER && sudo usermod -a -G input $USER && sudo usermod -a -G tty $USER
sudo sed "s/console/anybody/g" -i /etc/X11/Xwrapper.config
echo "startxfce4" > .xsession && chmod +x .xsession
sudo ./0build-xrdp-glamor-annotated.sh
sudo shutdown now &'

# Build Host list
readarray -td, HOST_LIST <<<"$HOSTS"; declare -p HOST_LIST;
printf '%s\n' "${HOST_LIST[@]}" > /tmp/resetfleet
echo
echo "Bootstrap Ubuntu-NFS:"
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
          if [ $count -eq 1 ]; then
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
    pssh $PSSH_OPTIONS "$cmd"
    sleep 10
  done
}

# Iterate PSSH Tasks
echo "Installing Kernel, Kernel Modules Intel Dependencies and starting XRDP"
if [ -z "$1" ]; then
  i=0
else
  i=$1
fi
for c in $(seq $i $(expr ${#COMMANDS[@]} - 1)); do
  waitForReboot
  sleep 10
  runCommands "${COMMANDS[$c]}"
  sleep 30
done

virtctl -n vms stop splinter-nfs --force=true --grace-period=0
kubectl -n vms delete vm ubuntu-nfs
sed 's/#autoattachGraphicsDevice/autoattachGraphicsDevice/g' -i build-vm.yaml
kubectl -n vms apply -f build-vm.yaml
