{ pkgs, lib, hasNvidia ? false, ... }:
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
  
  # Use kernel 6.16
  boot.kernelPackages = pkgs.linuxPackages_6_16;
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  boot.kernelModules = [ "i915" "vfio" "vfio_pci" "vfio_iommu_type1" ];
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
  ] ++ lib.optionals (!hasNvidia) [
    # SR-IOV parameters only for Intel-only systems
    "i915.enable_guc=3"
    "i915.max_vfs=7"
    "i915.force_probe=7d55"
    "module_blacklist=xe"  # Blacklist i915 for SR-IOV patched driver
    "vfio-pci.ids=8086:7d55"  # Reserve Intel GPU VFs for VFIO
  ];
  
  # SR-IOV Module - only for Intel-only systems (not hybrid NVIDIA+Intel)
  boot.extraModulePackages = lib.optionals (!hasNvidia) (with pkgs; [ i915-sriov-patched ]);

  # Kubernetes FS problem solver
  boot.kernel.sysctl."fs.inotify.max_user_instances" = 2147483647;
}
