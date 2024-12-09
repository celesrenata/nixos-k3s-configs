{ config, lib, pkgs, ... }:
{
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-compute-runtime.drivers
      #intel-media-driver
      #intel-vaapi-driver
      vpl-gpu-rt          # for newer GPUs on NixOS >24.05 or unstable
      #onevpl-intel-gpu  # for newer GPUs on NixOS <= 24.05
       # intel-media-sdk   # for older GPUs
    ];
  };
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.enableRedistributableFirmware = true;
  hardware.enableAllFirmware = true;
  # Custom iGPU Firmware for Arc iGPU
  hardware.firmware = [
    pkgs.linux-firmwareOverride
  ];

  # SR-IOV VF Configuration Service
  systemd.services.intel-gfx-sriov = {
    enable = true;
    description = "enable vGPUs";
    serviceConfig = {
      User = "root";
      Type = "oneshot";
      RemainAfterExit = "yes";
      ExecStart = [
        "${pkgs.bash}/bin/bash ${pkgs.intel-gfx-sriov-service}/scripts/configvfs.sh -e"
      ];
      ExecStop = [
        "${pkgs.bash}/bin/bash ${pkgs.intel-gfx-sriov-service}/scripts/configvfs.sh -d"
      ];
    };
    wantedBy = [ "multi-user.target" ];
  };
}
