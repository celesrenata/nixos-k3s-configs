{ config, lib, pkgs, inputs, nixpkgs-stable, ... }:

let
  cfg = config.gremlin.graphics;
  
  #base-nvidia-package = config.boot.kernelPackages.nvidiaPackages.mkDriver ({
  nvidia-package = config.boot.kernelPackages.nvidiaPackages.mkDriver ({
    version = "615.78.08";
    sha256_64bit = "sha256-Pj9t3cLudnoIGFMAr3vjyyhuznZpjS3eNSRZl4LQf/4=";
    sha256_aarch64 = "";
    openSha256 = "sha256-HBINiOjL0ZJLIAJeNIBYHBnwgUXtNwPPtnFpAI1YwF4=";
    settingsSha256 = "";
    persistencedSha256 = "sha256-RzeR6Ldct6MUxjnXRyThdh5Y3jjMehTVg85MtwuWNX4=";
  });
  
  #nvidia-package = base-nvidia-package // {
  #  open = base-nvidia-package.open.overrideAttrs (openAttrs: {
  #    postPatch = (openAttrs.postPatch or "") + ''
  #      substituteInPlace kernel-open/nvidia-uvm/uvm_va_range_device_p2p.c \
  #        --replace 'get_dev_pagemap(page_to_pfn(page), NULL)' 'get_dev_pagemap(page_to_pfn(page))'
  #    '';
  #  });
  #};
in {
  imports = [
    ./i915-sriov.nix
    ./i915-sriov-simple-fix.nix
  ];

  options.gremlin.graphics = {
    intel.enable = lib.mkEnableOption "Intel graphics support";
    intel.sriov = lib.mkEnableOption "Intel SR-IOV support";
    nvidia.enable = lib.mkEnableOption "NVIDIA graphics support";
  };

  config = lib.mkMerge [
    {
      hardware.graphics.enable = true;
      hardware.enableRedistributableFirmware = true;
      hardware.enableAllFirmware = true;
      hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    }

    (lib.mkIf cfg.intel.enable {
      # On these SR-IOV hosts the iGPU exposes 8 PCI functions (0000:00:02.0-.7).
      # A bare `intel_gpu_top` auto-picks the first function it enumerates, which
      # is often a VF (or a vfio-pci-bound function) with no i915 PMU, producing
      # "Failed to detect engines!". The physical function 0000:00:02.0 (card1)
      # is the one exposing the working PMU. This wrapper defaults the device to
      # the PF so plain `intel_gpu_top` just works, while still honoring an
      # explicit -d/--device passed by the user.
      environment.systemPackages = with pkgs; [
        nvtopPackages.full
        (lib.hiPrio (pkgs.writeShellScriptBin "intel_gpu_top" ''
          for a in "$@"; do
            case "$a" in
              -d|--device|-d*|--device=*)
                exec ${pkgs.intel-gpu-tools}/bin/intel_gpu_top "$@" ;;
            esac
          done
          exec ${pkgs.intel-gpu-tools}/bin/intel_gpu_top -d pci:slot=0000:00:02.0 "$@"
        ''))
      ];

      hardware.graphics.extraPackages = with pkgs; [
        intel-media-driver
        vpl-gpu-rt
      ];
    })

    (lib.mkIf cfg.nvidia.enable {
      nixpkgs.overlays = [
        (final: prev: {
          nvidia-container-toolkit = nixpkgs-stable.legacyPackages.x86_64-linux.nvidia-container-toolkit;
        })
      ];

      environment.systemPackages = with pkgs; [
        nvidia-container-toolkit
        (import nixpkgs-stable { system = "x86_64-linux"; config.allowUnfree = true; }).nvtopPackages.full
      ];

      boot.kernelParams = [
      ] ++ lib.optionals (!cfg.intel.enable) [
        "modprobe.blacklist=i915,xe"
      ] ++ lib.optionals (!config.services.xserver.enable) [
        "nvidia-drm.modeset=0"
      ];

      boot.blacklistedKernelModules = [ "nouveau" ] ++ 
        lib.optionals (!cfg.intel.enable) [ "i915" "xe" "intel_guc_submission" ];

      virtualisation.containerd.enable = true;

      hardware.graphics.enable32Bit = true;

      hardware.nvidia = {
        package = nvidia-package;
        nvidiaPersistenced = true;
        powerManagement.enable = false;
        open = true;
        nvidiaSettings = false;
        modesetting.enable = config.services.xserver.enable;
        prime.offload.enable = false;
      };

      services.xserver.videoDrivers = lib.mkIf cfg.nvidia.enable [ "nvidia" ];
    })
  ];
}
