{ config, lib, pkgs, resetMode ? false, ... }:

{
  imports = [
    ./boot.nix
    ./iscsi.nix
    ./remote-build.nix
    ./rgb.nix
  ];

  # Enable Flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.cores = 12;
  nixpkgs.config.allowUnfree = true;

  # Common overlays for all systems (removed intel-firmware overlay)
  nixpkgs.overlays = [
    (import ../overlays/kernel.nix)
  ];

  # SR-IOV setup service (driver is handled in graphics modules)
  systemd.services.i915-sriov-setup = lib.mkIf (config.gremlin.graphics.intel.sriov) {
    description = "Setup Intel i915 SR-IOV Virtual Functions";
    after = [ "multi-user.target" ];
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    
    script = ''
# Check if PF is bound to vfio-pci and rebind to xe if needed      if [ -L /sys/bus/pci/devices/0000:00:02.0/driver ]; then        current_driver=$(basename $(readlink /sys/bus/pci/devices/0000:00:02.0/driver))        if [ "$current_driver" = "vfio-pci" ]; then          echo "PF bound to vfio-pci, rebinding to xe driver..."          echo "0000:00:02.0" > /sys/bus/pci/drivers/vfio-pci/unbind          echo "0000:00:02.0" > /sys/bus/pci/drivers/xe/bind          sleep 2        fi      fi      
      # Check if SR-IOV is supported
      if [ ! -f /sys/devices/pci0000:00/0000:00:02.0/sriov_numvfs ]; then
        echo "SR-IOV not supported on this system"
        exit 0
      fi
      
      # Enable SR-IOV (create 7 VFs)
      if ! echo 7 > /sys/devices/pci0000:00/0000:00:02.0/sriov_numvfs; then
        echo "Failed to enable SR-IOV VFs"
        exit 1
      fi
      
      # Wait for VFs to be created
      sleep 3
      
      # Bind VFs to vfio-pci driver for passthrough
      for vf in /sys/devices/pci0000:00/0000:00:02.0/virtfn*; do
        if [ -d "$vf" ]; then
          vf_pci=$(basename $(readlink $vf))
          echo "Configuring VF $vf_pci for VFIO passthrough"
          
          # Unbind from current driver if bound
          if [ -e "$vf/driver" ]; then
            echo $vf_pci > $vf/driver/unbind 2>/dev/null || true
          fi
          
          # Bind to vfio-pci
          echo "8086 7d55" > /sys/bus/pci/drivers/vfio-pci/new_id 2>/dev/null || true
          echo $vf_pci > /sys/bus/pci/drivers/vfio-pci/bind 2>/dev/null || true
        fi
      done
      
      echo "SR-IOV VFs configured for VFIO passthrough"
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
  
  users.groups.video.gid = lib.mkForce 500;

  users.users.nixremote = {
    isNormalUser = true;
  };

  system.stateVersion = "25.05";
}
