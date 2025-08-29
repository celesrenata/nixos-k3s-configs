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
  # NVIDIA-only system - completely disable Intel graphics

  # Kernel parameters to disable Intel graphics completely
  boot.kernelParams = [
    # Disable Intel graphics drivers completely
    "module_blacklist=i915,xe,intel_guc_submission"
    # Disable Intel graphics at PCI level
    "pci=noaer"
    "intel_iommu=on"
    "iommu=pt"
  ];

  # Blacklist all Intel graphics modules
  boot.blacklistedKernelModules = [ "i915" "xe" "intel_guc_submission" ];

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
    # Remove all Intel packages - NVIDIA only
    extraPackages = [ ];
  };

  hardware.nvidia = {
    open = true;  # Use open source NVIDIA drivers
    package = nvidia-package;
    nvidiaSettings = true;
    # Force NVIDIA as primary GPU
    prime.offload.enable = false;
    modesetting.enable = true;
  };

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.enableRedistributableFirmware = true;
  hardware.enableAllFirmware = true;

  services.xserver = {
    enable = false;
    videoDrivers = [ "nvidia" ];
  };
}
