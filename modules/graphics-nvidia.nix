{ config, lib, pkgs, inputs, hasNvidia ? false, ... }:
let
  gpl_symbols_linux_615_patch = pkgs.fetchpatch {
    url = "https://github.com/CachyOS/kernel-patches/raw/914aea4298e3744beddad09f3d2773d71839b182/6.15/misc/nvidia/0003-Workaround-nv_vm_flags_-calling-GPL-only-code.patch";
    hash = "sha256-YOTAvONchPPSVDP9eJ9236pAPtxYK5nAePNtm2dlvb4=";
    stripLen = 1;
    extraPrefix = "kernel/";
  };
  nvidia-package = config.boot.kernelPackages.nvidiaPackages.mkDriver ({
    version = "580.76.05";
    sha256_64bit = "sha256-IZvmNrYJMbAhsujB4O/4hzY8cx+KlAyqh7zAVNBdl/0=";
    sha256_aarch64 = "";
    openSha256 = "sha256-xEPJ9nskN1kISnSbfBigVaO6Mw03wyHebqQOQmUg/eQ=";
    settingsSha256 = "sha256-ll7HD7dVPHKUyp5+zvLeNqAb6hCpxfwuSyi+SAXapoQ=";
    persistencedSha256 = "";
    patches = [ gpl_symbols_linux_615_patch ];
  });
in {
  # NVIDIA systems use upstream xe driver for Intel Arc (no SR-IOV)
  # xe is Intel's modern driver for Arc GPUs, avoiding i915 SR-IOV conflicts

  # Kernel parameters for xe driver (Intel Arc)
  boot.kernelParams = [
    # Enable xe driver for Intel Arc GPUs
    "xe.force_probe=7d55"  # Meteor Lake Arc Graphics
    # Blacklist i915 to prevent conflicts with xe
    "module_blacklist=i915"
  ];

  # Explicitly blacklist i915 driver to prevent conflicts with xe
  boot.blacklistedKernelModules = [ "i915" ];

  # Add NVIDIA-specific overlays
  nixpkgs.overlays = [
    (import ../overlays/nvidia-container-toolkit.nix)
  ];

  # Add NVIDIA-specific packages
  environment.systemPackages = with pkgs; [
    nvidia-container-toolkit
    nvtopPackages.full
  ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      intel-compute-runtime.drivers
      intel-media-driver
    ];
  };

  hardware.nvidia = {
    open = true;  # Explicitly set to true for newer drivers
    package = nvidia-package;
    nvidiaSettings = true;
  };

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.enableRedistributableFirmware = true;
  hardware.enableAllFirmware = true;

  # Use standard Linux firmware instead of custom override
  # Removed: pkgs.linux-firmwareOverride
  # This uses the standard NixOS firmware packages for better stability

  services.xserver = {
    enable = false;
    videoDrivers = [ "nvidia" ];
  };
}
