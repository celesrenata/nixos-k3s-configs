{ config, lib, pkgs, ... }:

{
  # Systemd service to enable Intel i915 SR-IOV virtual GPUs
  systemd.services.i915-sriov-enable = {
    description = "Enable Intel i915 SR-IOV Virtual GPUs";
    after = [ "multi-user.target" ];
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.bash}/bin/bash -c 'echo 7 > /sys/devices/pci0000:00/0000:00:02.0/sriov_numvfs'";
      ExecStop = "${pkgs.bash}/bin/bash -c 'echo 0 > /sys/devices/pci0000:00/0000:00:02.0/sriov_numvfs'";
    };
    
    # Only run if the SR-IOV sysfs file exists
    unitConfig = {
      ConditionPathExists = "/sys/devices/pci0000:00/0000:00:02.0/sriov_numvfs";
    };
  };
}
