{ config, pkgs, systemHostname, lib, ... }:

{
  imports = [
    ./sops.nix
    ./hardware-configuration.nix
    ./qdrant.nix
    # Qdrant 1.20 TurboQuant sidecar (bench/experiments) on 6433/6434.
    ./qdrant-turbo.nix
    # ArcForge host-native PF inference vertical slice (canary on port 8100,
    # coexists with the proven podman OVMS on 8000 for A/B validation).
    ./arcforge-slice.nix
    # ada-inference.nix removed 2026-10-22: replaced by the granite4-rtx
    # NixOS module (services.granite4-rtx) added in the flake for gremlin-1.
    #./wyoming.nix
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
