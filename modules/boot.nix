{ pkgs, nixpkgs-stable, lib, config, ... }:
let
  # Configure nixpkgs-stable with allowUnfree
  stable-pkgs = import nixpkgs-stable {
    system = "x86_64-linux";
    config.allowUnfree = true;
  };
in
{
  # Use the systemd-boot EFI boot loader.
  boot.initrd.systemd.enable = true;
  boot.loader = {
    systemd-boot.enable = true;
    efi = {
      canTouchEfiVariables = false;
    };
    grub = {
      efiSupport = true;
      efiInstallAsRemovable = true;
      device = "nodev";
    };
  };
  # KMS Module loading
  boot.initrd.kernelModules = [ "vmd" "md_mod" "raid0" ];
  boot.crashDump.enable = true;
  
  # Use kernel 6.17
  boot.kernelPackages = stable-pkgs.linuxPackages_6_17;
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  boot.kernelModules = [ "xe" "vfio" "vfio_pci" "vfio_iommu_type1" ];
  boot.supportedFilesystems = [ "nfs" ];
  
  # Kernel parameters - conditional based on graphics configuration
  boot.kernelParams = [
    # Common parameters for all systems
    "intel_iommu=on"
    "iommu=pt"
    "boot.shell_on_fail"
    "hugepagesz=1G"
    "hugepages=2"
    "hugepagesz=2M"
    "hugepages=512"
  ] ++ lib.optionals (config.gremlin.graphics.intel.sriov) [
    # SR-IOV parameters only for Intel-only systems
    "xe.enable_guc=3"
    "xe.max_vfs=7"
    "xe.force_probe=7d55"
    "module_blacklist=i915"  # Blacklist i915 for xe driver
    "vfio-pci.ids=8086:7d55"  # Reserve Intel GPU VFs for VFIO
  ];
  
  # xe driver has native SR-IOV support, no extra module packages needed

  # Kubernetes FS problem solver
  boot.kernel.sysctl."fs.inotify.max_user_instances" = 2147483647;
}
