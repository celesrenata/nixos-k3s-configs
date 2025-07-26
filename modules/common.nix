{ config, lib, pkgs, resetMode ? false, ... }:

{
  imports = [
    ./boot.nix
    ./iscsi.nix
    ./remote-build.nix
    ./rgb.nix
    ./i915-sriov.nix
  ];

  # Enable Flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.cores = 12;
  nixpkgs.config.allowUnfree = true;

  # Common overlays for all systems
  nixpkgs.overlays = [
    (import ../overlays/intel-firmware.nix)
    (import ../overlays/kernel.nix)
  ];

  # VMD Array configuration
  boot.swraid = {
    enable = true;
    mdadmConf = ''
      MAILADDR celes
    '';
  };

  # CA Certificate (conditional based on file existence)
  security.pki.certificateFiles = lib.optionals (builtins.pathExists (./.. + "/.config/Certificates/home.crt")) [
    (./.. + "/.config/Certificates/home.crt")
  ];

  # DistCC configuration
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

  # Disable standalone etcd - K3s uses its own embedded etcd cluster
  # This prevents port conflicts on 2380 between standalone etcd and K3s embedded etcd
  services.etcd.enable = false;

  nix.extraOptions = ''
    require-sigs = false
  '';
  
  time.timeZone = "America/Los_Angeles";

  # Common system packages
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
    intel-gpu-tools
    nix-index
    gcc14
    fastfetch
  ];

  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa.enable = true;
    jack.enable = true;
  };

  # Storage Management
  nix.optimise.automatic = true;
  nix.optimise.dates = [ "03:45" ];
  
  services.openiscsi = {
    enable = true;
    name = "${config.networking.hostName}-initiatorhost"; 
  };

  # Common user accounts
  users.users.celes = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
  };
  
  users.users.nixremote = {
    isNormalUser = true;
  };

  system.stateVersion = "25.05";
}
