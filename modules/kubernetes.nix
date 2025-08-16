{ config, lib, pkgs, hasNvidia ? false, ... }:
{
  environment.systemPackages = with pkgs; [
    docker
    runc
    k3s 
    kubernetes-helm
    multus-cni  # Make multus-cni available system-wide
  ] ++ lib.optionals hasNvidia [
    nvidia-container-toolkit
    libnvidia-container
  ];

  services.k3s = {
    enable = true;
    role = "server";
    token = "532a3cf6ea";
    clusterInit = (config.networking.hostName == "gremlin-1");
    serverAddr = lib.mkIf (config.networking.hostName != "gremlin-1") "https://10.1.1.12:6443";
    # Let K3s use its default Flannel
    extraFlags = toString [
      "--container-runtime-endpoint unix:///run/containerd/containerd.sock"
    ]; 
  };

  # Create a proper CNI directory with all needed binaries
  systemd.tmpfiles.rules = [
    "d /var/lib/rancher/k3s/data/cni 0755 root root -"
    "L+ /var/lib/rancher/k3s/data/cni/multus - - - - ${pkgs.multus-cni}/bin/multus"
    "L+ /var/lib/rancher/k3s/data/cni/multus-daemon - - - - ${pkgs.multus-cni}/bin/multus-daemon"
    "L+ /var/lib/rancher/k3s/data/cni/multus-shim - - - - ${pkgs.multus-cni}/bin/multus-shim"
    "L+ /var/lib/rancher/k3s/data/cni/thin_entrypoint - - - - ${pkgs.multus-cni}/bin/thin_entrypoint"
  ];

  virtualisation = {
    docker = {
      enable = true;
      package = pkgs.docker;
      rootless = {
        enable = true;
        setSocketVariable = true;
      };
    };
    containerd = {
      enable = true;
      settings = {
        plugins."io.containerd.grpc.v1.cri" = {
          cni = {
            bin_dir = "/var/lib/rancher/k3s/data/cni";
            conf_dir = "/var/lib/rancher/k3s/agent/etc/cni/net.d/";
          };
          containerd = {
            default_runtime_name = "runc";
            runtimes.runc = {
              runtime_type = "io.containerd.runc.v2";
            };
          };
        };
      };
    };
  };

  security.pam.loginLimits = [
    {domain = "*"; item = "memlock"; type = "-"; value = "unlimited";}
  ];
}
