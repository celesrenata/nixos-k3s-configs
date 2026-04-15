{ config, lib, pkgs, resetMode ? false, ... }:

{
  imports = [
    ./boot.nix
    ./iscsi.nix
    ./remote-build.nix
    ./rgb.nix
    ./distcc-triplet.nix
  ];

  # Enable Flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.cores = 16;
  nix.settings.require-sigs = false;
  nixpkgs.config.allowUnfree = true;

  # Increase file descriptor limits for build processes
  security.pam.loginLimits = [
    { domain = "*"; type = "soft"; item = "nofile"; value = "65536"; }
    { domain = "*"; type = "hard"; item = "nofile"; value = "65536"; }
  ];
  
  systemd.settings.Manager.DefaultLimitNOFILE = 65536;

  # Common overlays for all systems (removed intel-firmware overlay)
  nixpkgs.overlays = [
    (import ../overlays/kernel.nix)
  ];

  # SR-IOV setup service (driver is handled in graphics modules)
  systemd.services.i915-sriov-setup = lib.mkIf (config.gremlin.graphics.intel.sriov) {
    description = "Setup Intel xe SR-IOV Virtual Functions";
    after = [ "systemd-modules-load.service" ];
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = "10s";
    };
    
    script = ''
      sleep 5
      echo 7 > /sys/devices/pci0000:00/0000:00:02.0/sriov_numvfs
      sleep 2
      for vf in /sys/devices/pci0000:00/0000:00:02.0/virtfn*; do
        [ -d "$vf" ] || continue
        vf_pci=$(basename $(readlink $vf))
        echo "vfio-pci" > /sys/bus/pci/devices/$vf_pci/driver_override
        echo $vf_pci > /sys/bus/pci/drivers/i915/unbind 2>/dev/null || true
        echo $vf_pci > /sys/bus/pci/drivers/vfio-pci/bind 2>/dev/null || true
      done
    '';
    
    preStop = ''
      # Disable SR-IOV VFs
      echo 0 > /sys/devices/pci0000:00/0000:00:02.0/sriov_numvfs || true
    '';
  };

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
    perf
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

  #   services.exo = {
  #     enable = true;
  #     accelerator = "cpu";  # Changed from "cuda" to "cpu" for Linux compatibility
  #     port = 52415;
  #     openFirewall = true;
  #   };

  # Storage Management
  nix.optimise.automatic = true;
  nix.optimise.dates = [ "03:45" ];
  
  services.openiscsi = {
    enable = true;
    name = "${config.networking.hostName}-initiatorhost"; 
  };

  # Longhorn expects iscsiadm at a standard FHS path via nsenter
  systemd.tmpfiles.rules = [
    "L+ /usr/sbin/iscsiadm - - - - /run/current-system/sw/bin/iscsiadm"
  ];

  # Common user accounts
  users.users.celes = {
    isNormalUser = true;
    extraGroups = [ "wheel" "docker" ];
  };
  
  users.groups.video.gid = lib.mkForce 500;

  users.users.nixremote = {
    isNormalUser = true;
  };

  system.stateVersion = "25.11";
}
