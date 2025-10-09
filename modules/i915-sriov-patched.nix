{ config, lib, pkgs, inputs, ... }:

{
  # Patched xe-sriov with comprehensive fixes for kernel 6.15.7
  # This module provides the patched driver for all systems
  
  nixpkgs.overlays = [
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
  boot.extraModulePackages = [ pkgs.xe-sriov-patched ];
}
