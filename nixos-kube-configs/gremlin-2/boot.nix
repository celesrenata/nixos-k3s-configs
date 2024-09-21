{ pkgs, ... }:
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
  
  # See Kernel Overlay
  boot.kernelPackages = pkgs.kernel69;
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  boot.kernelModules = [ "i915" ];
  boot.supportedFilesystems = [ "nfs" ];
  
  # Setup SR-IOV Required Parameters for Arc iGPU
  boot.kernelParams = [
    "intel_iommu=on"
    "iommu=pt"
    "i915.enable_guc=3"
    "i915.max_vfs=7"
    "i915.force_probe=7d55"
    "boot.shell_on_fail"
  ];
  
  # SR-IOV Module
  boot.extraModulePackages = with pkgs; [ intel-gfx-sriov ];
}