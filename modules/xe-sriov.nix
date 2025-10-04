{ config, lib, pkgs, inputs, ... }:

{
  # Intel xe SR-IOV configuration
  # xe is the modern unified Intel GPU driver with native SR-IOV support
  
  # Kernel parameters required for xe SR-IOV
  boot.kernelParams = [
    # Enable IOMMU for SR-IOV
    "intel_iommu=on"
    "iommu=pt"
    
    # xe SR-IOV configuration
    "xe.enable_guc=3"          # Enable GuC (required for SR-IOV)
    "xe.max_vfs=7"             # Maximum number of Virtual Functions
    "xe.force_probe=7d55"      # Force probe for Meteor Lake Arc Graphics
    
    # Blacklist i915 driver to avoid conflicts
    "module_blacklist=i915"
    
    # Automatically bind VFs to VFIO for passthrough
    "vfio-pci.ids=8086:7d55"
  ];

  # Enable VFIO kernel modules
  boot.kernelModules = [ "vfio" "vfio_iommu_type1" "vfio_pci" "xe" ];

  # Configure modprobe options for xe
  boot.extraModprobeConfig = ''
    # xe SR-IOV options
    options xe enable_guc=3 max_vfs=7 force_probe=7d55
    
    # Blacklist i915 to prevent conflicts
    blacklist i915
  '';
}
