final: prev: {
  linux_6_18_rc6 = (prev.linuxPackages_6_17.kernel.override {
    argsOverride = {
      version = "6.18.0-rc6";
      modDirVersion = "6.18.0-rc6";
      src = prev.fetchurl {
        url = "https://git.kernel.org/torvalds/t/linux-6.18-rc6.tar.gz";
        hash = "sha256-GjwLJDLWG5gpCBbd4YS1tPgQ8byHhGa/AXDuUehcbTY=";
      };
      kernelPatches = [
        {
          name = "xe-mtl-sriov";
          patch = ./. + "/../mtl-sriov.patch";
        }
      ];
    };
  });
  
  linuxPackages_6_18_rc6 = prev.linuxPackagesFor final.linux_6_18_rc6;
}
