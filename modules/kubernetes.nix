{ config, lib, pkgs, hasNvidia ? false, ... }:
let
  # buildEnv that bundles flannel + the full CNI plugin set + multus
  fullCNIPlugins = pkgs.buildEnv {
    name = "cni-full";
    paths = with pkgs; [
      cni-plugin-flannel
      multus-cni
      cni-plugins
    ];
  };
  
  # Multus CNI configuration that delegates to Flannel
  multusConfig = pkgs.writeText "00-multus.conflist" (builtins.toJSON {
    cniVersion = "1.0.0";
    name = "multus-cni-network";
    type = "multus";
    capabilities = {
      portMappings = true;
    };
    delegates = [
      {
        name = "cbr0";
        cniVersion = "1.0.0";
        plugins = [
          {
            type = "flannel";
            delegate = {
              hairpinMode = true;
              forceAddress = true;
              isDefaultGateway = true;
            };
          }
          {
            type = "portmap";
            capabilities = {
              portMappings = true;
            };
          }
          {
            type = "bandwidth";
            capabilities = {
              bandwidth = true;
            };
          }
        ];
      }
    ];
    kubeconfig = "/var/lib/rancher/k3s/server/cred/admin.kubeconfig";
  });
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
    extraFlags = (toString [
      "--container-runtime-endpoint unix:///run/containerd/containerd.sock"
      "--flannel-backend=none"
    ]); 
  };

  systemd.services = lib.mkMerge [
    {
      k3s-containerd-setup = {
        serviceConfig.Type = "oneshot";
        requiredBy = ["k3s.service"];
        before = ["k3s.service"];
        script = ''
          mkdir -p /var/lib/rancher/k3s/agent/etc/containerd
          mkdir -p /var/lib/rancher/k3s/agent/etc/cni/net.d
          
          # Install Multus CNI configuration
          cp ${multusConfig} /var/lib/rancher/k3s/agent/etc/cni/net.d/00-multus.conflist
          
          cat << EOFCONFIG > /var/lib/rancher/k3s/agent/etc/containerd/config.toml.tmpl
          {{ template "base" . }}
          version = 2

          [plugins."io.containerd.grpc.v1.cri".cni]
            bin_dir  = "${fullCNIPlugins}/bin"
            conf_dir = "/var/lib/rancher/k3s/agent/etc/cni/net.d"

          [plugins."io.containerd.grpc.v1.cri".containerd]
            default_runtime_name = "runc"

            [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
              runtime_type = "io.containerd.runc.v2"
          EOFCONFIG
        '';
      };
    }
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
            bin_dir = "${fullCNIPlugins}/bin";
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
