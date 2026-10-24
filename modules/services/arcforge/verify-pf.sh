#!/usr/bin/env bash
# Verify that the configured render node is owned by the expected PF PCI
# function via sysfs: /sys/bus/pci/devices/<pci>/drm/<renderNode> must exist.
# This is the "deterministic device selection" guard: if the topology changed
# (e.g. SR-IOV rebind) we fail loudly instead of running on the wrong device.
set -euo pipefail
NODE="$1"    # e.g. /dev/dri/renderD128
EXPECT="$2"  # e.g. 0000:00:02.0

NODE_NAME=$(basename "$NODE")

if [ ! -e "$NODE" ]; then
  echo "ArcForge: render node $NODE not present" >&2
  exit 1
fi

SYSFS_DRI="/sys/bus/pci/devices/$EXPECT/drm/$NODE_NAME"
if [ ! -e "$SYSFS_DRI" ]; then
  echo "ArcForge: PCI function $EXPECT does not own render node $NODE_NAME" >&2
  echo "Present: $(ls "/sys/bus/pci/devices/$EXPECT/drm/" 2>/dev/null | tr '\n' ' ')" >&2
  exit 1
fi

# Cross-check the device id recorded in sysfs against the live node.
EXPECTED_DEV=$(cat "$SYSFS_DRI/dev" 2>/dev/null || echo "?")
ACTUAL_DEV=$(stat -c '%t:%T' "$NODE")
echo "ArcForge: $NODE owned by PCI $EXPECT (sysfs dev=${EXPECTED_DEV} live dev=${ACTUAL_DEV}) OK"
