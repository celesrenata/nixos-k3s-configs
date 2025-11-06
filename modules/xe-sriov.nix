{ config, lib, ... }:

{
  # Intel xe SR-IOV configuration using native kernel 6.18 support
  
  boot.kernelParams = lib.mkIf (config.gremlin.graphics.intel.enable && config.gremlin.graphics.intel.sriov) [
    "intel_iommu=on"
    "iommu=pt"
    "xe.max_vfs=7"
    "xe.force_probe=7d55"
    "module_blacklist=i915"
  ];

  boot.kernelModules = lib.mkIf (config.gremlin.graphics.intel.enable && config.gremlin.graphics.intel.sriov) [
    "vfio" "vfio_iommu_type1" "vfio_pci" "xe"
  ];

  boot.extraModprobeConfig = lib.mkIf (config.gremlin.graphics.intel.enable && config.gremlin.graphics.intel.sriov) ''
    options xe max_vfs=7 force_probe=7d55
    blacklist i915
  '';
}
