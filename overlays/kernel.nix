final: prev: {
  linux_6_18_rc4 = (prev.linuxPackages_6_17.kernel.override {
    argsOverride = {
      version = "6.18.0-rc4";
      modDirVersion = "6.18.0-rc4";
      src = prev.fetchurl {
        url = "https://git.kernel.org/torvalds/t/linux-6.18-rc4.tar.gz";
        hash = "sha256-DtR8sFwexWyzondmRXXaSbHZ7W/QK2dMwp/zfg+TsKE=";
      };
    };
  });
  
  linuxPackages_6_18_rc4 = prev.linuxPackagesFor final.linux_6_18_rc4;
}
