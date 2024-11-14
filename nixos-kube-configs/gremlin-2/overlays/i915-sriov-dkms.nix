prev: final:
rec {
  intel-gfx-sriov = prev.stdenv.mkDerivation {
    name = "intel-gfx-sriov-${prev.linuxPackages_6_6.kernel.modDirVersion}";

    passthru.moduleName = "intel-gfx-sriov";

    src = prev.fetchFromGitHub {
      owner = "strongtz";
      repo = "i915-sriov-dkms";
      rev = "e26ce8952e465762fc0743731aa377ec0b2889ff";
      sha256 = "sha256-O+7ZehoVOYYdCTboF9XGBR9G6I72987AdbbF1JkrsBc=";
    };
  
    hardeningDisable = [ "pic" ];
  
    nativeBuildInputs = final.linuxPackages_6_6.kernel.moduleBuildDependencies;
   
    makeFlags = [
      "KVERSION=${final.linuxPackages_6_6.kernel.modDirVersion}"
      "KDIR=${final.linuxPackages_6_6.kernel.dev}/lib/modules/${final.linuxPackages_6_6.kernel.modDirVersion}/build"
    ];
    buildFlags = [
      "KERNEL_DIR=${final.linuxPackages_6_6.kernel.dev}/lib/modules/${final.linuxPackages_6_6.kernel.modDirVersion}/build"
    ];
    buildPhase = ''
      make -j8 -C ${final.pkgs.kernel611.kernel.dev}/lib/modules/${final.linuxPackages_6_6.kernel.modDirVersion}/build M=$(pwd) modules
    '';
  
    installPhase = ''
      install -D i915.ko $out/lib/modules/${final.linuxPackages_6_6.kernel.modDirVersion}/kernel/drivers/gpu/drm/i915/i915.ko
    '';
  };
}
