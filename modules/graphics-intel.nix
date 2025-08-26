{ config, lib, pkgs, inputs, hasNvidia ? false, ... }:

{
  # Import SR-IOV module only for Intel-only systems (not hybrid NVIDIA+Intel)
  imports = lib.optionals (!hasNvidia) [
    ./i915-sriov.nix
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
