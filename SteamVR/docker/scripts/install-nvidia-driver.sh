#!/bin/bash
set -e

# Skip if already installed
if [ -f /usr/lib/x86_64-linux-gnu/.nvidia-installed ]; then
    echo "=== NVIDIA driver already installed ==="
    exit 0
fi

echo "=== Detecting host NVIDIA driver version ==="
if [ -f /proc/driver/nvidia/version ]; then
    NVIDIA_VERSION=$(cat /proc/driver/nvidia/version | grep "Kernel Module" | awk '{print $8}')
    echo "Detected host NVIDIA driver version: $NVIDIA_VERSION"
else
    echo "WARNING: Could not detect host NVIDIA driver, using default 580.82.07"
    NVIDIA_VERSION="580.82.07"
fi

NVIDIA_URL="https://us.download.nvidia.com/XFree86/Linux-x86_64/${NVIDIA_VERSION}/NVIDIA-Linux-x86_64-${NVIDIA_VERSION}.run"

echo "Downloading NVIDIA driver from: $NVIDIA_URL"
cd /tmp
wget -q "$NVIDIA_URL" -O nvidia-installer.run || {
    echo "ERROR: Failed to download driver version $NVIDIA_VERSION"
    exit 1
}
chmod +x nvidia-installer.run

echo "Installing NVIDIA driver (X.Org components only)..."
./nvidia-installer.run --silent --no-kernel-module --no-kernel-module-source --no-backup --no-rpms --no-nouveau-check --no-cc-version-check --install-libglvnd --x-prefix=/usr --x-module-path=/usr/lib/xorg/modules --x-library-path=/usr/lib/x86_64-linux-gnu --x-sysconfig-path=/etc/X11/xorg.conf.d

touch /usr/lib/x86_64-linux-gnu/.nvidia-installed
echo "=== NVIDIA driver $NVIDIA_VERSION installation complete ==="
rm -f /tmp/nvidia-installer.run
