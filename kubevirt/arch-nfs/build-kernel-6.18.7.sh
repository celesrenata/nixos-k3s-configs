#!/bin/bash
set -e

KERNEL_VERSION="6.18.7"
BUILD_DIR="/tmp/kernel-build"

# Install dependencies
sudo apt-get update
sudo apt-get install -y libelf-dev flex bison libssl-dev bc kmod cpio debhelper kernel-wedge distcc libdw-dev

# Create build directory
mkdir -p $BUILD_DIR
cd $BUILD_DIR

# Download kernel source if not already present
if [ ! -d "linux-${KERNEL_VERSION}" ]; then
  if [ ! -f "linux-${KERNEL_VERSION}.tar.xz" ]; then
    wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KERNEL_VERSION}.tar.xz
  fi
  tar xf linux-${KERNEL_VERSION}.tar.xz
fi
cd linux-${KERNEL_VERSION}

# Copy current config as base
cp /boot/config-$(uname -r) .config

# Apply MTL SR-IOV patch if not already applied
if ! grep -q "has_sriov = true" drivers/gpu/drm/xe/xe_pci.c; then
  patch -p1 < /tmp/mtl-sriov.patch
fi

# Enable required options for xe driver
scripts/config --enable CONFIG_DRM_XE
scripts/config --enable CONFIG_DRM_XE_DISPLAY
scripts/config --set-val CONFIG_DRM_XE_FORCE_PROBE '""'

# Auto-accept defaults for new options
make olddefconfig

# Setup distcc
export DISTCC_HOSTS="gremlin-1/16,lzo gremlin-2/16,lzo gremlin-3/16,lzo gremlin-4/16,lzo"
JOBS=$((16 * 4))  # 16 jobs per host * 4 hosts

echo "DISTCC_HOSTS=$DISTCC_HOSTS"

# Build deb packages
make -j${JOBS} bindeb-pkg LOCALVERSION=-custom KDEB_PKGVERSION=$(make kernelversion)-1 CC="distcc gcc" HOSTCC=gcc

echo "Kernel packages built in $(dirname $PWD)"
ls -lh ../*.deb
