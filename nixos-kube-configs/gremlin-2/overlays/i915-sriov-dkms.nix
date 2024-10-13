prev: final:
rec {
  intel-gfx-sriov = prev.stdenv.mkDerivation {
    name = "intel-gfx-sriov-${prev.linuxPackages.kernel.modDirVersion}";

    passthru.moduleName = "intel-gfx-sriov";

    src = prev.fetchFromGitHub {
      owner = "strongtz";
      repo = "i915-sriov-dkms";
      rev = "52020b4f469f9bd40c48e296e9a3e826a11df177";
      sha256 = "sha256-YwPf8G1v4cVy/EEG3iMKe2wXIYrJY+l+7YZ95kE7T1s=";
    };
  
    hardeningDisable = [ "pic" ];
  
    nativeBuildInputs = final.linuxPackages.kernel.moduleBuildDependencies;
   
    makeFlags = [
      "KVERSION=${final.linuxPackages.kernel.modDirVersion}"
      "KDIR=${final.linuxPackages.kernel.dev}/lib/modules/${final.linuxPackages_6_10.kernel.modDirVersion}/build"
    ];
    buildFlags = [
      "KERNEL_DIR=${final.linuxPackages.kernel.dev}/lib/modules/${final.linuxPackages_6_10.kernel.modDirVersion}/build"
    ];
    buildPhase = ''
      make -j8 -C ${final.pkgs.kernel611.kernel.dev}/lib/modules/${final.linuxPackages_6_10.kernel.modDirVersion}/build M=$(pwd) modules
    '';
  
    installPhase = ''
      install -D i915.ko $out/lib/modules/${final.linuxPackages_6_10.kernel.modDirVersion}/kernel/drivers/gpu/drm/i915/i915.ko
    '';
  };
}
