final: prev: {
  linux_6_19_sriov = (prev.linuxPackages_6_19.kernel.override {
    argsOverride = {
      kernelPatches = [
        {
          name = "xe-mtl-sriov";
          patch = ./. + "/../mtl-sriov.patch";
        }
      ];
    };
  });
  
  linuxPackages_6_19_sriov = prev.linuxPackagesFor final.linux_6_19_sriov;
}
