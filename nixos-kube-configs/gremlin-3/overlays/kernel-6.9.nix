final: prev: {
        kernel69 = prev.pkgs.linuxPackagesFor (prev.pkgs.linux_6_9.override {
          structuredExtraConfig = with prev.lib.kernel; {
            DRM_I915_PXP = yes;
            INTEL_MEI_PXP = module;
          };
          ignoreConfigErrors = true;
        });
}
