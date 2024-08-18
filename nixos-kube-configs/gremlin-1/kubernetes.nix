{ config, pkgs, ... }:
{
  # System Packages
  environment.systemPackages = with pkgs; [
    k3s
    kubernetes-helm
  ];
  # Kubernetes Service
  services.k3s = {
    enable = true;
    role = "server";
    token = "532a3cf6ea"; 
    clusterInit = true;
  };

  # MySQL
  #services.mysql = {
  #  enable = true;
  #  package = pkgs.mariadb;
  #};

  # Storage Service
  virtualisation.containerd = {
    enable = true;
    settings =
      let
        fullCNIPlugins = pkgs.buildEnv {
          name = "full-cni";
          paths = with pkgs;[
            cni-plugins
            cni-plugin-flannel
          ];
        };
      in {
        plugins."io.containerd.grpc.v1.cri".cni = {
          bin_dir = "${fullCNIPlugins}/bin";
          conf_dir = "/var/lib/rancher/k3s/agent/etc/cni/net.d/";
        };
        # Optionally set private registry credentials here instead of using /etc/rancher/k3s/registries.yaml
        # plugins."io.containerd.grpc.v1.cri".registry.configs."registry.example.com".auth = {
        #  username = "";
        #  password = "";
        # };
      };
  };
  # TODO describe how to enable zfs snapshotter in containerd
  services.k3s.extraFlags = toString [
    "--container-runtime-endpoint unix:///run/containerd/containerd.sock"
    #"--disable servicelb"
    #"--disable traefik"
  ];
}
