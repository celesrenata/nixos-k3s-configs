final: prev: {
  linux_6_18_sriov = (prev.linuxPackages_6_18.kernel.override {
    argsOverride = {
      kernelPatches = [
        {
          name = "xe-mtl-sriov";
          patch = ./. + "/../mtl-sriov.patch";
        }
      ];
    };
  });
  
  linuxPackages_6_18_sriov = prev.linuxPackagesFor final.linux_6_18_sriov;
}
