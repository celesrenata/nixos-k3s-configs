# Template hardware configuration for gremlin-4
# This will need to be replaced with actual hardware-configuration.nix
# when gremlin-4 is deployed
{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "xhci_pci" "thunderbolt" "vmd" "nvme" "usbhid" "usb_storage" "sd_mod" "sdhci_pci" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  # PLACEHOLDER - Replace with actual filesystem configuration when deploying gremlin-4
  fileSystems."/" =
    { device = "/dev/disk/by-uuid/5c20d972-fa0e-4455-805e-b56f42d7ca81";
      fsType = "btrfs";
      options = [ "compress=zstd" "subvol=root" ];
    };

  fileSystems."/nix" =
    { device = "/dev/disk/by-uuid/5c20d972-fa0e-4455-805e-b56f42d7ca81";
      fsType = "btrfs";
      options = [ "compress=zstd" "subvol=nix" ];
    };

  fileSystems."/home" =
    { device = "/dev/disk/by-uuid/5c20d972-fa0e-4455-805e-b56f42d7ca81";
      fsType = "btrfs";
      options = [ "compress=zstd" "subvol=home" ];
    };

  fileSystems."/var/lib" =
    { device = "/dev/disk/by-uuid/5c20d972-fa0e-4455-805e-b56f42d7ca81";
      fsType = "btrfs";
      options = [ "compress=zstd" "subvol=varlib" ];
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/9686-5EB2";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

  swapDevices = [ { device = "/dev/disk/by-uuid/b452cd91-d05f-413a-8fc3-633f27c4d851"; } ];

  # Enables DHCP on each ethernet interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
