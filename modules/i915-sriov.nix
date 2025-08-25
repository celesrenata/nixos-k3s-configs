{ config, lib, pkgs, inputs, ... }:

{
  # Intel i915 SR-IOV configuration
  # The actual SR-IOV functionality is provided by the i915-sriov DKMS module
  # imported in flake.nix as i915-sriov.nixosModules.default
  
  # Kernel parameters required for i915 SR-IOV
  boot.kernelParams = [
    # Enable IOMMU for SR-IOV
    "intel_iommu=on"
    "iommu=pt"
    
    # i915 SR-IOV configuration
    "i915.enable_guc=3"        # Enable GuC (required for SR-IOV)
    "i915.max_vfs=7"           # Maximum number of Virtual Functions
    "i915.force_probe=7d55"    # Force probe for Meteor Lake Arc Graphics
    
    # Blacklist xe driver to avoid conflicts
    "module_blacklist=xe"
    
    # Automatically bind VFs to VFIO for passthrough
    "vfio-pci.ids=8086:7d55"
  ];

  # Enable VFIO kernel modules
  boot.kernelModules = [ "vfio" "vfio_iommu_type1" "vfio_pci" ];

  # Optional: Configure modprobe options (redundant with kernel params but explicit)
  boot.extraModprobeConfig = ''
    # i915 SR-IOV options
    options i915 enable_guc=3 max_vfs=7 force_probe=7d55
  '';
}
