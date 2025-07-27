{ config, lib, pkgs, inputs, ... }:

{
  # Import the shared i915-sriov patched module
  imports = [
    ./i915-sriov-patched.nix
  ];

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

  # Use standard Linux firmware instead of custom override
  # Removed: pkgs.linux-firmwareOverride
  # This uses the standard NixOS firmware packages for better stability
}
