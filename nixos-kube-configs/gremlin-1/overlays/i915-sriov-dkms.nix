prev: final:
rec {
  intel-gfx-sriov = prev.stdenv.mkDerivation {
    name = "intel-gfx-sriov-${prev.kernelPXP.kernel.modDirVersion}";

    passthru.moduleName = "intel-gfx-sriov";

    src = prev.fetchFromGitHub {
      owner = "bbaa-bbaa";
      repo = "i915-sriov-dkms";
      rev = "07cc8896d28687cbe6416e64373fc21d8b383423";
      sha256 = "sha256-RVSXLx17ZFjGO1G/g/crAkdBAyGlEqM0iPFDRwnynzc=";
    };
  
    hardeningDisable = [ "pic" ];
  
    nativeBuildInputs = prev.kernelPXP.kernel.moduleBuildDependencies;
   
    makeFlags = [
      "KVERSION=${prev.kernelPXP.kernel.modDirVersion}"
      "KDIR=${prev.kernelPXP.kernel.dev}/lib/modules/${prev.kernelPXP.kernel.modDirVersion}/build"
    ];
    buildFlags = [
      "KERNEL_DIR=${prev.kernelPXP.kernel.dev}/lib/modules/${prev.kernelPXP.kernel.modDirVersion}/build"
    ];
    buildPhase = ''
      make -j8 -C ${prev.pkgs.kernelPXP.kernel.dev}/lib/modules/${prev.kernelPXP.kernel.modDirVersion}/build M=$(pwd) modules
    '';
  
    installPhase = ''
      install -D i915.ko $out/lib/modules/${prev.kernelPXP.kernel.modDirVersion}/kernel/drivers/gpu/drm/i915/i915.ko
    '';
  };
}
