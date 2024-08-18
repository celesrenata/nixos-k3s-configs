# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, lib, pkgs, ... }:
{
  imports =
    [ # Include the results of the hardware scan.
      ./kubernetes.nix
      ./remote-build.nix
      ./hardware-configuration.nix
      ./iscsi.nix
      ./virtualisation.nix
    ];
  # Enable Flakes.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [
    (import ./overlays/i915-sriov-dkms.nix)
    (import ./overlays/intel-gfx-sriov.nix)
    (import ./overlays/kernel-6.9.nix)
    (import ./overlays/intel-firmware.nix)
  ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;
  boot.loader.grub.device = "nodev";
  boot.loader.grub.efiSupport = true;
  boot.kernelPackages = pkgs.kernel69;
  boot.kernelModules = [ "i915" ];
  boot.supportedFilesystems = [ "nfs" ];
  boot.kernelParams = [
    "intel_iommu=on"
    "iommu=pt"
    "i915.enable_guc=3"
    "i915.max_vfs=7"
    "i915.force_probe=7d55"
  ];
  boot.extraModulePackages = with pkgs; [ intel-gfx-sriov ];
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-compute-runtime.drivers
      #intel-media-driver
      #intel-vaapi-driver
        vpl-gpu-rt          # for newer GPUs on NixOS >24.05 or unstable
      #onevpl-intel-gpu  # for newer GPUs on NixOS <= 24.05
       # intel-media-sdk   # for older GPUs
    ];
  };
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.enableRedistributableFirmware = true;
  hardware.enableAllFirmware = true;
  hardware.firmware = [
    pkgs.linux-firmwareOverride
  ];

  # Reset
  # services.etcd.enable = false;
  # KUBELET_PATH=$(mount | grep kubelet | cut -d' ' -f3);
  # sudo ${KUBELET_PATH:+umount $KUBELET_PATH}
  # sudo rm -rf /etc/rancher/{k3s,node};
  # sudo rm -rf /var/lib/{rancher/k3s,kubelet,longhorn,etcd,cni}
  ## services.etcd.enable = false;
  ## sudo rm -rf /var/lib/etcd/
  ### sudo reboot
  #### services.etcd.enable = true;
  ##### services.etcd.enable = true;
  
  # Networking
  networking.hostName = "gremlin-3";
  services.rpcbind.enable = true;
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "yes";
  networking.firewall.enable = false;
  nix.extraOptions = ''
    require-sigs = false
  '';
  time.timeZone = "America/Los_Angeles";

  # Virtualisation
  systemd.services.intel-gfx-sriov = {
    enable = true;
    description = "enable vGPUs";
    serviceConfig = {
      User = "root";
      Type = "oneshot";
      RemainAfterExit = "yes";
      ExecStart = [
        "${pkgs.bash}/bin/bash ${pkgs.intel-gfx-sriov-service}/scripts/configvfs.sh -e"
      ];
      ExecStop = [
        "${pkgs.bash}/bin/bash ${pkgs.intel-gfx-sriov-service}/scripts/configvfs.sh -d"
      ];
    };
    wantedBy = [ "multi-user.target" ];
  };
#  virtualisation.kvmgt = {
#    enable = true;
#  };
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true;
      ovmf = {
        enable = true;
        packages = [(pkgs.OVMF.override {
          secureBoot = true;
          tpmSupport = true;
        }).fd];
      };
    };
  };
  programs.virt-manager.enable = true;
  virtualisation.docker.enable = true;
  virtualisation.docker.storageDriver = "btrfs";

  environment.systemPackages = with pkgs; [
    vim
    wpa_supplicant
    curl
    git
    nmap
    btop
    usbutils
    pciutils
    waypipe
    screen
    nfs-utils
    openiscsi
    nvtopPackages.intel
    intel-gpu-tools
    nix-index
  ];

  # CA Certificate
  security.pki.certificateFiles = [
    /kubedata-remote/certs/home.crt
  ];
  # Storage Management
  nix.optimise.automatic = true;
  nix.optimise.dates = [ "03:45" ];
  services.openiscsi = {
    enable = true;
    name = "${config.networking.hostName}-initiatorhost"; 
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.celes = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ]; # Enable ‘sudo’ for the user.
  };
  users.users.nixremote = {
    isNormalUser = true;
  };

  system.stateVersion = "24.11"; # Did you read the comment?

}

