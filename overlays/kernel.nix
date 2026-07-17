final: prev: {
  linux_7_1_sriov = (prev.linuxPackages_7_1.kernel.override {
    argsOverride = {
      kernelPatches = [
        {
          name = "xe-mtl-sriov";
          patch = ./. + "/../mtl-sriov.patch";
        }
      ];
    };
  });
  
  linuxPackages_7_1_sriov = prev.linuxPackagesFor final.linux_7_1_sriov;
}
