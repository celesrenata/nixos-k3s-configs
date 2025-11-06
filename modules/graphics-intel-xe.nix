{ config, lib, pkgs, ... }:

{
  # Enable Xe driver for Meteor Lake
  boot.kernelParams = [
    "i915.force_probe=!7d55"  # Disable i915 for Meteor Lake
    "xe.force_probe=7d55"     # Enable Xe for Meteor Lake
  ];

  # Load Xe and VFIO drivers
  boot.kernelModules = [ "xe" "vfio-pci" ];

  # Hardware acceleration
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-media-driver
      intel-vaapi-driver
      libvdpau-va-gl
    ];
  };
  
  # Create SR-IOV VFs on boot
  systemd.services.xe-sriov-setup = {
    description = "Setup Xe SR-IOV Virtual Functions";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udev-settle.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      # Find Xe device
      XE_DEVICE=$(find /sys/devices -name "sriov_totalvfs" | head -1 | xargs dirname)
      if [ -n "$XE_DEVICE" ]; then
        echo "Found Xe device: $XE_DEVICE"
        echo 7 > "$XE_DEVICE/sriov_numvfs"
        echo "Created 7 SR-IOV VFs"
      fi
    '';
  };
}
