# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, pkgs, ... }:
{
  imports =
    [ # Include the results of the hardware scan.
      ./boot.nix
      ./graphics.nix
      ./hardware-configuration.nix
      ./iscsi.nix
      ./kubernetes.nix
      ./monitoring.nix
      ./networking.nix
      ./remote-build.nix
      ./ups.nix
      ./virtualisation.nix
    ];

  # Enable Flakes.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.cores = 12;
  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [
    #(import ./overlays/distcc.nix)
    (import ./overlays/i915-sriov-dkms.nix)
    (import ./overlays/intel-firmware.nix)
    (import ./overlays/intel-gfx-sriov.nix)
    (import ./overlays/kernel.nix)
  ];

  # VMD Array
  boot.swraid = {
    enable = true;
    mdadmConf = "
      MAILADDR celes
    ";
  };

  # Networking
  networking.hostName = "gremlin-2";
  systemd.network = {
    networks = {
      "40-bond0" = {
        matchConfig.Name = "bond0";
        linkConfig = {
          RequiredForOnline = "routable";
        };
        address = [ "10.1.1.13/24" ];
        gateway = [ "10.1.1.1" ];
      };
    };
  };

  # DistCC.
  services.distccd = {
    enable = true;
    allowedClients = [
      "192.168.42.0/25"
      "10.1.1.0/24"
      "10.42.0.0/16"
    ];
    stats.enable = true;
    zeroconf = true;
  };

  # Reset Cluster
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
  
  nix.extraOptions = ''
    require-sigs = false
  '';
  time.timeZone = "America/Los_Angeles";

  # System Packages
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
    gcc14
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

  system.stateVersion = "24.05";
}

