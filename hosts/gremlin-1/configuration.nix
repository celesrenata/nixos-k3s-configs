{ config, pkgs, systemHostname, lib, ... }:

{
  imports = [
    ./sops.nix
    ./hardware-configuration.nix
    ./wyoming.nix
  ];

  # Make sure the same influx binaries are available in your shell
  environment.systemPackages = with pkgs; [
    lmstudio
    steam-run
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
      };
    };
  };

  # K3s node configuration - NVIDIA GPU only
  services.k3s.extraFlags = lib.mkForce (let
    bondAddr = builtins.head config.systemd.network.networks."40-bond0".address;
    nodeIp = lib.removeSuffix "/24" bondAddr;
  in toString [
    "--container-runtime-endpoint unix:///run/containerd/containerd.sock"
    "--node-ip ${nodeIp}"
    "--flannel-iface bond0"
    "--node-label gpu=nvidia"
    "--node-label workload=gpu-only"
  ]);

}
