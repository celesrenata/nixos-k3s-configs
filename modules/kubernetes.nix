{ config, lib, pkgs, hasNvidia ? false, ... }:
let
  fullCNIPlugins = pkgs.buildEnv {
    name = "cni-full";
    paths = with pkgs; [
      cni-plugin-flannel
      multus-cni
      cni-plugins
    ];
  };
in
{
  environment.systemPackages = with pkgs; [
    docker
    runc
    k3s 
    kubernetes-helm
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
    # Remove flannel-backend=none - let K3s use its default Flannel
    extraFlags = (toString [
      "--container-runtime-endpoint unix:///run/containerd/containerd.sock"
    ]); 
  };

  systemd.services.k3s-containerd-setup = {
    serviceConfig.Type = "oneshot";
    requiredBy = ["k3s.service"];
    before = ["k3s.service"];
    script = ''
      mkdir -p /var/lib/rancher/k3s/agent/etc/containerd
      mkdir -p /var/lib/rancher/k3s/data/cni
      
      # Copy CNI binaries to the K3s CNI directory
      cp -r ${fullCNIPlugins}/bin/* /var/lib/rancher/k3s/data/cni/
      
      cat << EOFCONFIG > /var/lib/rancher/k3s/agent/etc/containerd/config.toml.tmpl
      {{ template "base" . }}
      version = 2

      [plugins."io.containerd.grpc.v1.cri".cni]
        bin_dir  = "/var/lib/rancher/k3s/data/cni"
        conf_dir = "/var/lib/rancher/k3s/agent/etc/cni/net.d"

      [plugins."io.containerd.grpc.v1.cri".containerd]
        default_runtime_name = "runc"

        [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
          runtime_type = "io.containerd.runc.v2"
      EOFCONFIG
    '';
  };

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
