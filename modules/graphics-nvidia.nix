{ config, lib, pkgs, ... }:
let
  gpl_symbols_linux_615_patch = pkgs.fetchpatch {
    url = "https://github.com/CachyOS/kernel-patches/raw/914aea4298e3744beddad09f3d2773d71839b182/6.15/misc/nvidia/0003-Workaround-nv_vm_flags_-calling-GPL-only-code.patch";
    hash = "sha256-YOTAvONchPPSVDP9eJ9236pAPtxYK5nAePNtm2dlvb4=";
    stripLen = 1;
    extraPrefix = "kernel/";
  };
  nvidia-package = config.boot.kernelPackages.nvidiaPackages.mkDriver ({
    version = "575.64.05";
    sha256_64bit = "sha256-hfK1D5EiYcGRegss9+H5dDr/0Aj9wPIJ9NVWP3dNUC0=";
    sha256_aarch64 = "";
    openSha256 = "sha256-mcbMVEyRxNyRrohgwWNylu45vIqF+flKHnmt47R//KU=";
    settingsSha256 = "sha256-o2zUnYFUQjHOcCrB0w/4L6xI1hVUXLAWgG2Y26BowBE=";
    persistencedSha256 = "sha256-2g5z7Pu8u2EiAh5givP5Q1Y4zk4Cbb06W37rf768NFU=";
    patches = [ gpl_symbols_linux_615_patch ];
  });
in {
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

  # Custom iGPU Firmware for Arc iGPU
  hardware.firmware = [
    pkgs.linux-firmwareOverride
  ];

  # Enable Intel SR-IOV support via the flake (for Intel iGPU alongside NVIDIA)
  boot.extraModulePackages = [ pkgs.i915-sriov ];

  services.xserver = {
    enable = false;
    videoDrivers = [ "nvidia" ];
  };

  systemd.services = {
    # Note: SR-IOV configuration is handled by the i915-sriov flake module
    # No custom systemd services needed here
  };
}
