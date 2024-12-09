final: prev: {
        kernelPXP = prev.pkgs.linuxPackagesFor (prev.pkgs.linux.override {
          argsOverride = rec {
            src = prev.pkgs.fetchurl {
              url = "mirror://kernel/linux/kernel/v6.x/linux-${version}.tar.xz";
              sha256 = "sha256-UkhYhS9YaanvF96LHm5/rwW8ssRivJazwk2/gu3jc88=";
            };
            version = "6.10.12";
            modDirVersion = "6.10.12";
          };
          extraConfig = ''
            DRM_I915_PXP y
            INTEL_MEI_PXP m
          '';
        });
}
