final: prev: {
        # Linux 6.15 kernel - upgraded from 6.6 for better Meteor Lake support and SR-IOV compatibility
        # PXP support commented out as it's not needed for strongtz/i915-sriov-dkms
        # Uncomment the override block below if PXP support is needed in the future
        kernelPXP = prev.pkgs.linuxPackages_6_16;
        
        # kernelPXP = prev.pkgs.linuxPackagesFor (prev.pkgs.linux_6_6.override {
        #   extraConfig = ''
        #     DRM_I915_PXP y
        #     INTEL_MEI_PXP m
        #   '';
        # });
}
