{ config, lib, pkgs, inputs, ... }:

{
  # Intel xe SR-IOV configuration using bbaa-bbaa's xe-sriov driver
  
  nixpkgs.overlays = lib.mkIf (config.gremlin.graphics.intel.enable && config.gremlin.graphics.intel.sriov) [
    (final: prev: {
      xe-sriov-patched = prev.stdenv.mkDerivation {
        name = "xe-sriov-${config.boot.kernelPackages.kernel.modDirVersion}";
        src = inputs.i915-sriov;
        hardeningDisable = [ "pic" ];
        nativeBuildInputs = config.boot.kernelPackages.kernel.moduleBuildDependencies;
        
        makeFlags = [
          "KVERSION=${config.boot.kernelPackages.kernel.modDirVersion}"
          "KDIR=${config.boot.kernelPackages.kernel.dev}/lib/modules/${config.boot.kernelPackages.kernel.modDirVersion}/build"
        ];
        buildPhase = ''
          echo "Building xe-sriov for kernel ${config.boot.kernelPackages.kernel.modDirVersion}"
          make -j$NIX_BUILD_CORES -C ${config.boot.kernelPackages.kernel.dev}/lib/modules/${config.boot.kernelPackages.kernel.modDirVersion}/build M=$(pwd) modules
        '';
        installPhase = ''
          install -D drivers/gpu/drm/xe/xe.ko $out/lib/modules/${config.boot.kernelPackages.kernel.modDirVersion}/kernel/drivers/gpu/drm/xe/xe.ko
        '';
      };
    })
  ];

  # Enable xe SR-IOV support
  boot.extraModulePackages = lib.mkIf (config.gremlin.graphics.intel.enable && config.gremlin.graphics.intel.sriov) [ pkgs.xe-sriov-patched ];
  
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
