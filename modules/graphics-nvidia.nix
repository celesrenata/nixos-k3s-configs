{ config, lib, pkgs, inputs, hasNvidia ? false, ... }:
let
  nvidia-package = config.boot.kernelPackages.nvidiaPackages.mkDriver ({
    version = "580.105.08";
    sha256_64bit = "sha256-2cboGIZy8+t03QTPpp3VhHn6HQFiyMKMjRdiV2MpNHU=";
    sha256_aarch64 = "";
    openSha256 = "sha256-FGmMt3ShQrw4q6wsk8DSvm96ie5yELoDFYinSlGZcwQ=";
    settingsSha256 = "sha256-YvzWO1U3am4Nt5cQ+b5IJ23yeWx5ud1HCu1U0KoojLY=";
    persistencedSha256 = "";
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
    (import nixpkgs-stable { system = "x86_64-linux"; config.allowUnfree = true; }).nvtopPackages.full
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
