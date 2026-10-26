{ config, lib, pkgs, inputs, ... }:

{
  # Intel i915 SR-IOV configuration
  # The actual SR-IOV functionality is provided by the i915-sriov DKMS module
  
  # i915 SR-IOV kernel parameters (iommu params are in boot.nix)
  boot.kernelParams = [
    "i915.enable_guc=3"
    "i915.max_vfs=7"
    "i915.force_probe=7d55"
    "module_blacklist=xe"
  ];

  # Enable VFIO kernel modules
  boot.kernelModules = [ "vfio" "vfio_iommu_type1" "vfio_pci" ];
}
