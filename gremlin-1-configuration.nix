# This file demonstrates what should be in /etc/nixos/configuration.nix on gremlin-1
# Host-specific configuration for RTX 4070 Ti SUPER inference stack

{ config, pkgs, ... }:

{
  # Hostname and basic system settings
  networking.hostName = "gremlin-1";
  networking.domain = "local";

  # Network configuration  
  networking.interfaces.bond0.ipv4.addresses = [
    { address = "10.1.1.12"; prefixLength = 24; }
  ];

  # GPU and CUDA settings
  hardware.nvidia = {
    # Enable proprietary driver for Ada architecture (SM89)
    open = false;
    # Configure power management
    pm = "auto";
    # Enable nvidia-settings GUI
    nvidiaSettings = true;
  };

  # Enable OpenGL and graphics
  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
  };

  # Add required system packages for inference
  environment.systemPackages = with pkgs; [
    # CUDA libraries (must match the driver)
    cudaPackages.cudatoolkit
    cudaPackages.libcublas
    cudaPackages.libcurand
    # Inference runtime
    llama.cpp
    # For model conversion and management  
    gguf-py  # For tensor fixing (when needed)
    # System tools
    curl
    jq
    tmux
    htop
  ];

  # NVIDIA GPU monitoring
  services.nixos-generate-udev-rules = true;
  services.xserver.displayManager.slim.enable = false;
  services.xserver.displayManager.gdm.enable = false;
  services.xserver.enable = false; # This is a headless server

  # Inference user account setup
  users.users.inference = {
    isNormalUser = true;
    group = "inference";
    home = "/var/lib/inference";
    createHome = true;
    # No shell needed for service account
    shell = pkgs.nologin;
  };

  users.groups.inference = {};

  # GPU-related service monitoring
  systemd.services.nvidia-persistenced = {
    description = "NVIDIA Persistence Daemon";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "forking";
      ExecStart = "${pkgs.nvidiaPersistenced}/bin/nvidia-persistenced";
    };
  };

  # Set up model storage directory with appropriate permissions
  systemd.tmpfiles.places = [
    { 
      path = "/var/lib/qwen-models"; 
      mode = "0755";
      user = "inference";
      group = "inference";
    }
  ];

  # Performance and security settings
  boot.kernelSysctl = {
    # GPU memory tuning
    "vm.swappiness" = 1;
    "vm.dirty_ratio" = 15;
    "vm.dirty_background_ratio" = 5;
    
    # Increase file descriptor limits 
    "fs.file-max" = 1000000;
    "fs.nr_open" = 1000000;
  };

  # Logging and monitoring
  services.journald.extraConfig = ''
    MaxLevelConsole=info
    MaxFileSec=24h
  '';

  # Disable unnecessary services on headless server
  services.avahi.enable = false;
  services.printing.enable = false;
  services.xserver.enable = false;
  
  # Firewall and security
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 8082 ]; # SSH and inference API

  # Enable Nix daemon for remote builds if needed
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.trusted-users = [ "root" "inference" ];
  
  # Package caching for remote builds if configured
  nix.settings.substituters = [ "https://cache.nixos.org/" ];
  nix.settings.trusted-substituters = [ "https://cache.nixos.org/" ];

  # Systemd tuning for GPU workloads
  systemd.settings = {
    DefaultCPUQuota = "100%";
    DefaultIOWeight = 100;
  };

  # This is where specific service configurations would go
  # that are specific to the Qwen3.8 optimization approach on this host
}