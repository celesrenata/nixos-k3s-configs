#!/usr/bin/env bash
# Copy NVIDIA libraries from NixOS location to standard location
# This is needed because Kubernetes hostPath volumes don't follow symlinks

set -e

echo "Copying NVIDIA libraries to /usr/local/nvidia/lib64..."
mkdir -p /usr/local/nvidia/lib64
rm -rf /usr/local/nvidia/lib64/*
cp -rL /run/opengl-driver/lib/* /usr/local/nvidia/lib64/

echo "Verifying libnvidia-ml.so exists..."
ls -lh /usr/local/nvidia/lib64/libnvidia-ml.so*

echo "Done!"
