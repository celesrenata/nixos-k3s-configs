{ config, lib, pkgs, ... }:
let
  nvidia-package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
      version = "570.124.04";
      sha256_64bit = "sha256-G3hqS3Ei18QhbFiuQAdoik93jBlsFI2RkWOBXuENU8Q=";
      sha256_aarch64 = "";
      openSha256 = "sha256-KCGUyu/XtmgcBqJ8NLw/iXlaqB9/exg51KFx0Ta5ip0=";
      settingsSha256 = "sha256-LNL0J/sYHD8vagkV1w8tb52gMtzj/F0QmJTV1cMaso8=";
      persistencedSha256 = "sha256-SHSdnGyAiRH6e0gYMYKvlpRSH5KYlJSA1AJXPm7MDRk=";
  };
in rec {
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-compute-runtime.drivers
      #intel-media-driver
      #intel-vaapi-driver
      vpl-gpu-rt          # for newer GPUs on NixOS >24.05 or unstable
      #onevpl-intel-gpu  # for newer GPUs on NixOS <= 24.05
       # intel-media-sdk   # for older GPUs
    ];
  };
  hardware.nvidia = {
    open = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    nvidiaSettings = true;
  };
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.enableRedistributableFirmware = true;
  hardware.enableAllFirmware = true;
  # Custom iGPU Firmware for Arc iGPU
  hardware.firmware = [
    pkgs.linux-firmwareOverride
  ];
  services.xserver = {
    enable = false;
    videoDrivers = [ "nvidia" ];
  };
  systemd.services = {
    # SR-IOV VF Configuration Service
    intel-gfx-sriov = {
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
  };
}
