{ config, lib, pkgs, inputs, ... }:

{
  # Patched xe-sriov with comprehensive fixes for kernel 6.15.7
  # This module provides the patched driver for all systems
  
  nixpkgs.overlays = lib.mkIf (config.gremlin.graphics.intel.enable && config.gremlin.graphics.intel.sriov) [
    (final: prev: {
      xe-sriov-patched = prev.stdenv.mkDerivation {
        name = "xe-sriov-${config.boot.kernelPackages.kernel.modDirVersion}";
        src = inputs.i915-sriov;
        hardeningDisable = [ "pic" ];
        nativeBuildInputs = config.boot.kernelPackages.kernel.moduleBuildDependencies;
        
        makeFlags = [
          "KVERSION=${config.boot.kernelPackages.kernel.modDirVersion}"
          "KDIR=${config.boot.kernelPackages.kernel.dev}/lib/modules/${config.boot.kernelPackages.kernel.modDirVersion}/build"
        ];
        buildPhase = ''
          echo "Building comprehensively patched xe-sriov for kernel ${config.boot.kernelPackages.kernel.modDirVersion}"
          make -j$NIX_BUILD_CORES -C ${config.boot.kernelPackages.kernel.dev}/lib/modules/${config.boot.kernelPackages.kernel.modDirVersion}/build M=$(pwd) modules
        '';
        installPhase = ''
          install -D drivers/gpu/drm/xe/xe.ko $out/lib/modules/${config.boot.kernelPackages.kernel.modDirVersion}/kernel/drivers/gpu/drm/xe/xe.ko
        '';
      };
    })
  ];

  # Enable Intel SR-IOV support with comprehensive patches
  boot.extraModulePackages = lib.mkIf (config.gremlin.graphics.intel.enable && config.gremlin.graphics.intel.sriov) [ pkgs.xe-sriov-patched ];
  
  # Blacklist stock xe module so only our patched version can load
  boot.blacklistedKernelModules = lib.mkIf (config.gremlin.graphics.intel.enable && config.gremlin.graphics.intel.sriov) [ "xe" ];
  
  # Our patched xe module will be available via extraModulePackages and loaded by the kernel when needed
}
}
