{ config, lib, pkgs, ... }:
let
  nvidia-package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
      version = "555.52.04";
      sha256_64bit = "sha256-nVOubb7zKulXhux9AruUTVBQwccFFuYGWrU1ZiakRAI=";
      sha256_aarch64 = "sha256-Kt60kTTO3mli66De2d1CAoE3wr0yUbBe7eqCIrYHcWk=";
      openSha256 = "sha256-wDimW8/rJlmwr1zQz8+b1uvxxxbOf3Bpk060lfLKuy0=";
      settingsSha256 = "sha256-PMh5efbSEq7iqEMBr2+VGQYkBG73TGUh6FuDHZhmwHk=";
      persistencedSha256 = "sha256-KAYIvPjUVilQQcD04h163MHmKcQrn2a8oaXujL2Bxro=";
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
    package = nvidia-package;
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
