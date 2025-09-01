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
    persistencedSha256 = "sha256-bs3bUi8LgBu05uTzpn2ugcNYgR5rzWEPaTlgm0TIpHY=";
    patches = [ gpl_symbols_linux_615_patch ];
  });
in {
  # NVIDIA-only headless server with stability improvements

  # Optimized kernel parameters for CUDA containers + containerd + k3s
  boot.kernelParams = [
    "intel_iommu=on"              # ensure IOMMU active
    "iommu=pt"                    # pass-through mapping; lowers overhead / flakiness
    "modprobe.blacklist=i915,xe"  # keep Intel gfx out on this node
    "pcie_aspm=off"               # disable PCIe ASPM to prevent Xid/link errors
    "nmi_watchdog=0"              # disable NMI watchdog to prevent panic reboots
    "softlockup_panic=0"          # disable softlockup panic to prevent reboots
    "nvidia-drm.modeset=0"        # disable KMS on headless server
  ];

  # Blacklist Intel graphics modules + nouveau for stability
  boot.blacklistedKernelModules = [ "i915" "xe" "intel_guc_submission" "nouveau" ];

  # Add NVIDIA-specific overlays
  nixpkgs.overlays = [
    (import ../overlays/nvidia-container-toolkit.nix)
  ];

  # Add NVIDIA-specific packages
  environment.systemPackages = with pkgs; [
    nvidia-container-toolkit
    nvtopPackages.full
  ];

  # CDI-based container runtime configuration
  virtualisation.containerd.enable = true;
  hardware.nvidia-container-toolkit.enable = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = [ ];
  };

  # NVIDIA headless server configuration
  hardware.nvidia = {
    package = nvidia-package;
    nvidiaPersistenced = false;
    powerManagement.enable = false;
    open = true;
    nvidiaSettings = true;
    modesetting.enable = false;       # disable KMS on headless server
    prime.offload.enable = false;
  };

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.enableRedistributableFirmware = true;
  hardware.enableAllFirmware = true;

  services.xserver = {
    enable = false;                   # headless server
    videoDrivers = [ "nvidia" ];
  };
}
