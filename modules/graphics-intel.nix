{ config, lib, pkgs, ... }:

{
  # Add Intel-specific packages
  environment.systemPackages = with pkgs; [
    nvtopPackages.intel
  ];

  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-compute-runtime.drivers
      vpl-gpu-rt          # for newer GPUs on NixOS >24.05 or unstable
    ];
  };

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.enableRedistributableFirmware = true;
  hardware.enableAllFirmware = true;

  # Custom iGPU Firmware for Arc iGPU
  hardware.firmware = [
    pkgs.linux-firmwareOverride
  ];

  # Enable Intel SR-IOV support via the flake
  boot.extraModulePackages = [ pkgs.i915-sriov ];
}
