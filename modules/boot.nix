{ pkgs, nixpkgs-stable, lib, config, ... }:
let
  stable-pkgs = import nixpkgs-stable {
    system = "x86_64-linux";
    config.allowUnfree = true;
  };
in
{
  boot.initrd.systemd.enable = true;
  boot.loader = {
    systemd-boot.enable = true;
    systemd-boot.configurationLimit = 10;
    efi.canTouchEfiVariables = false;
  };
  boot.initrd.kernelModules = [ "vmd" "md_mod" "raid0" ];
  boot.kernelPackages = pkgs.linuxPackages_7_0_sriov;
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  boot.kernelModules = [ "i915" "vfio" "vfio_pci" "vfio_iommu_type1" ];
  boot.supportedFilesystems = [ "nfs" ];
  
  boot.kernelParams = [
    "intel_iommu=on"
    "iommu=pt"
    "boot.shell_on_fail"
    "nmi_watchdog=0"
    "softlockup_panic=0"
  ];

  boot.kernel.sysctl."fs.inotify.max_user_instances" = 65536;
  
  powerManagement.cpuFreqGovernor = "ondemand";
}
