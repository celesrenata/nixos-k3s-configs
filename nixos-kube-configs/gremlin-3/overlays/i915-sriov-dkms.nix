prev: final:
rec {
  intel-gfx-sriov = prev.stdenv.mkDerivation {
    name = "intel-gfx-sriov-${prev.linuxPackages.kernel.modDirVersion}";

    passthru.moduleName = "intel-gfx-sriov";

    src = prev.fetchFromGitHub {
      owner = "strongtz";
      repo = "i915-sriov-dkms";
      rev = "94c61cc345f7e145b6f1ff336846ccc0ae807b86";
      sha256 = "sha256-JmGBVfXlxqCommGXVSx8ecz+1e/VC0Crc+4PadQHJsI=";
    };
  
    hardeningDisable = [ "pic" ];
  
    nativeBuildInputs = final.linuxPackages.kernel.moduleBuildDependencies;
   
    makeFlags = [
      "KVERSION=${final.linuxPackages.kernel.modDirVersion}"
      "KDIR=${final.linuxPackages.kernel.dev}/lib/modules/${final.linuxPackages.kernel.modDirVersion}/build"
    ];
    buildFlags = [
      "KERNEL_DIR=${final.linuxPackages.kernel.dev}/lib/modules/${final.linuxPackages.kernel.modDirVersion}/build"
    ];
    buildPhase = ''
      make -C ${final.pkgs.kernel69.kernel.dev}/lib/modules/${final.linuxPackages.kernel.modDirVersion}/build M=$(pwd) modules
    '';
  
    installPhase = ''
      install -D i915.ko $out/lib/modules/${final.linuxPackages.kernel.modDirVersion}/kernel/drivers/gpu/drm/i915/i915.ko
    '';
  };
}
