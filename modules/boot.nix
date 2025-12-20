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
    efi.canTouchEfiVariables = false;
    grub = {
      efiSupport = true;
      efiInstallAsRemovable = true;
      device = "nodev";
    };
  };
  boot.initrd.kernelModules = [ "vmd" "md_mod" "raid0" ];
  boot.kernelPackages = pkgs.linuxPackages_6_18_sriov;
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  boot.kernelModules = [ "xe" "vfio" "vfio_pci" "vfio_iommu_type1" ];
  boot.supportedFilesystems = [ "nfs" ];
  
  boot.kernelParams = [
    "intel_iommu=on"
    "iommu=pt"
    "boot.shell_on_fail"
    "hugepagesz=1G"
    "hugepages=2"
    "hugepagesz=2M"
    "hugepages=512"
    "nmi_watchdog=0"
    "softlockup_panic=0"
    "intel_pstate=passive"
    "processor.max_cstate=1"
    "intel_pstate.max_perf_pct=75"
  ] ++ lib.optionals (config.gremlin.graphics.intel.sriov) [
    "xe.enable_guc=3"
    "xe.max_vfs=7"
    "xe.force_probe=7d55"
    "module_blacklist=i915"
  ];

  boot.kernel.sysctl."fs.inotify.max_user_instances" = 2147483647;
  
  powerManagement.cpuFreqGovernor = "ondemand";
}
