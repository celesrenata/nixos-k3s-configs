{ config, lib, pkgs, inputs, nixpkgs-stable, ... }:

let
  cfg = config.gremlin.graphics;
  
  base-nvidia-package = config.boot.kernelPackages.nvidiaPackages.mkDriver ({
    version = "580.105.08";
    sha256_64bit = "sha256-2cboGIZy8+t03QTPpp3VhHn6HQFiyMKMjRdiV2MpNHU=";
    sha256_aarch64 = "";
    openSha256 = "sha256-FGmMt3ShQrw4q6wsk8DSvm96ie5yELoDFYinSlGZcwQ=";
    settingsSha256 = "sha256-YvzWO1U3am4Nt5cQ+b5IJ23yeWx5ud1HCu1U0KoojLY=";
    persistencedSha256 = "sha256-qh8pKGxUjEimCgwH7q91IV7wdPyV5v5dc5/K/IcbruI=";
    postPatch = ''
      substituteInPlace kernel-open/nvidia-uvm/uvm_va_range_device_p2p.c \
        --replace 'get_dev_pagemap(page_to_pfn(page), NULL)' 'get_dev_pagemap(page_to_pfn(page))'
    '';
  });
  
  nvidia-package = base-nvidia-package // {
    open = base-nvidia-package.open.overrideAttrs (openAttrs: {
      postPatch = (openAttrs.postPatch or "") + ''
        substituteInPlace kernel-open/nvidia-uvm/uvm_va_range_device_p2p.c \
          --replace 'get_dev_pagemap(page_to_pfn(page), NULL)' 'get_dev_pagemap(page_to_pfn(page))'
      '';
    });
  };
in {
  imports = [
    ./xe-sriov.nix
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
      environment.systemPackages = with pkgs; [
        nvtopPackages.intel
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
        nvidiaSettings = true;
        modesetting.enable = config.services.xserver.enable;
        prime.offload.enable = false;
      };

      services.xserver.videoDrivers = lib.mkIf cfg.nvidia.enable [ "nvidia" ];
    })
  ];
}
