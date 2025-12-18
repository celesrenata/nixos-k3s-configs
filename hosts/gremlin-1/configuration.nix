{ config, pkgs, systemHostname, lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # Make sure the same influx binaries are available in your shell
  environment.systemPackages = with pkgs; [
    influxdb2
    influxdb2-cli
    jq
  ];

  # System-specific networking
  networking.hostName = systemHostname;
  systemd.network = {
    networks = {
      "40-bond0" = {
        matchConfig.Name = "bond0";
        linkConfig.RequiredForOnline = "routable";
        address = [ "10.1.1.12/24" ];
        gateway = [ "10.1.1.1" ];
      };
    };
  };

  # K3s node configuration - NVIDIA GPU only
  services.k3s.extraFlags = lib.mkForce (toString [
    "--container-runtime-endpoint unix:///run/containerd/containerd.sock"
    "--node-label gpu=nvidia"
    "--node-label workload=gpu-only"
  ]);


}

