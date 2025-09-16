{ config, lib, pkgs, inputs, ... }:

{
  # Simple i915-sriov fix - only fixes the installPhase path issue
  
  nixpkgs.overlays = [
    (final: prev: {
      i915-sriov-patched = prev.stdenv.mkDerivation {
        name = "i915-sriov-${config.boot.kernelPackages.kernel.modDirVersion}";
        src = inputs.i915-sriov;
        hardeningDisable = [ "pic" ];
        nativeBuildInputs = config.boot.kernelPackages.kernel.moduleBuildDependencies;
        
        makeFlags = [
          "KVERSION=${config.boot.kernelPackages.kernel.modDirVersion}"
          "KDIR=${config.boot.kernelPackages.kernel.dev}/lib/modules/${config.boot.kernelPackages.kernel.modDirVersion}/build"
        ];
        buildPhase = ''
          echo "Building i915-sriov for kernel ${config.boot.kernelPackages.kernel.modDirVersion}"
          make -j$NIX_BUILD_CORES -C ${config.boot.kernelPackages.kernel.dev}/lib/modules/${config.boot.kernelPackages.kernel.modDirVersion}/build M=$(pwd) modules
        '';
        installPhase = ''
          install -D drivers/gpu/drm/i915/i915.ko $out/lib/modules/${config.boot.kernelPackages.kernel.modDirVersion}/kernel/drivers/gpu/drm/i915/i915.ko
        '';
      };
    })
  ];

  # Enable Intel SR-IOV support
  boot.extraModulePackages = [ pkgs.i915-sriov-patched ];
}
