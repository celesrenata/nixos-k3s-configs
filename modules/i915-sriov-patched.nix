{ config, lib, pkgs, inputs, ... }:

{
  # Patched i915-sriov with comprehensive fixes for kernel 6.15.7
  # This module provides the patched driver for all systems
  
  nixpkgs.overlays = [
    (final: prev: {
      i915-sriov-patched = prev.stdenv.mkDerivation {
        name = "i915-sriov-${config.boot.kernelPackages.kernel.modDirVersion}";
        src = inputs.i915-sriov;
        hardeningDisable = [ "pic" "format" ];
        nativeBuildInputs = config.boot.kernelPackages.kernel.moduleBuildDependencies;
        
      };
    })
  ];

  # Enable Intel SR-IOV support with comprehensive patches
  boot.extraModulePackages = [ pkgs.i915-sriov-patched ];
}
