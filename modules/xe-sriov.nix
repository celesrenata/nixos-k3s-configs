{ config, lib, ... }:

{
  # Intel xe SR-IOV configuration using native kernel 6.19 support
  # Note: kernel parameters are set in boot.nix to avoid duplicates
  
  boot.kernelModules = lib.mkIf (config.gremlin.graphics.intel.enable && config.gremlin.graphics.intel.sriov) [
    "vfio" "vfio_iommu_type1" "vfio_pci" "xe"
  ];

  boot.extraModprobeConfig = lib.mkIf (config.gremlin.graphics.intel.enable && config.gremlin.graphics.intel.sriov) ''
    options xe enable_guc=3 max_vfs=7 force_probe=7d55
    blacklist i915
  '';
}
