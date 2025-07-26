{ config, lib, pkgs, hasNvidia ? false, ... }:
let
  # buildEnv that bundles flannel + the full CNI plugin set (bridge, host-local, vlan, etc)
  fullCNIPlugins = pkgs.buildEnv {
    name = "cni-full";
    paths = with pkgs; [
      cni-plugin-flannel  # your primary CNI for pod networking
      cni-plugins         # the meta-package that contains vlan, bridge, host-local…
    ];
  };
in
{
  # System Packages
  environment.systemPackages = with pkgs; [
    docker
    runc
    k3s 
    kubernetes-helm
  ] ++ lib.optionals hasNvidia [
    nvidia-container-toolkit
  ];

  # Kubernetes Service
  services.k3s = {
    enable = true;
    role = "server";
    token = "532a3cf6ea"; 
    clusterInit = true;
    extraFlags = (toString [
      "--container-runtime-endpoint unix:///run/containerd/containerd.sock"
    ]); 
  };

  systemd.services = lib.mkMerge [
    {
      k3s-containerd-setup = {
        serviceConfig.Type = "oneshot";
        requiredBy = ["k3s.service"];
        before = ["k3s.service"];
        script = if hasNvidia then ''
          mkdir -p /var/lib/rancher/k3s/agent/etc/containerd
          cat << EOF > /var/lib/rancher/k3s/agent/etc/containerd/config.toml.tmpl
          {{ template "base" . }}
          version = 2

          [plugins."io.containerd.grpc.v1.cri".cni]
            bin_dir  = "${fullCNIPlugins}/bin"
            conf_dir = "/var/lib/rancher/k3s/agent/etc/cni/net.d"

          [plugins."io.containerd.grpc.v1.cri".containerd]
            default_runtime_name = "nvidia"

            [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
              runtime_type = "io.containerd.runc.v2"

            [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia]
              privileged_without_host_devices = false
              runtime_type = "io.containerd.runc.v2"

              [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia.options]
                BinaryName = "/run/current-system/sw/bin/nvidia-container-runtime"

          [plugins."io.containerd.grpc.v1.cri"]
            enable_cdi = true
            cdi_spec_dirs = [ "/var/run/cdi" ]
          EOF
        '' else ''
          mkdir -p /var/lib/rancher/k3s/agent/etc/containerd
          cat << EOF > /var/lib/rancher/k3s/agent/etc/containerd/config.toml.tmpl
          {{ template "base" . }}
          version = 2

          [plugins."io.containerd.grpc.v1.cri".cni]
            bin_dir  = "${fullCNIPlugins}/bin"
            conf_dir = "/var/lib/rancher/k3s/agent/etc/cni/net.d"

          [plugins."io.containerd.grpc.v1.cri".containerd]
            default_runtime_name = "runc"

            [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
              runtime_type = "io.containerd.runc.v2"
          EOF
        '';
      };
    }
    (lib.mkIf hasNvidia {
      nvidia-container-toolkit-cdi-generator = {
        environment.LD_LIBRARY_PATH = "${config.hardware.nvidia.package}/lib";
      };
    })
  ];

  # NVIDIA container toolkit - only enable if NVIDIA is present
  hardware.nvidia-container-toolkit = lib.mkIf hasNvidia {
    enable = true;
    mount-nvidia-executables = true; 
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
        plugins."io.containerd.grpc.v1.cri" = lib.mkMerge [
          {
            cni = {
              bin_dir = "${fullCNIPlugins}/bin";
              conf_dir = "/var/lib/rancher/k3s/agent/etc/cni/net.d/";
            };
            containerd = lib.mkMerge [
              {
                default_runtime_name = if hasNvidia then "nvidia" else "runc";
                runtimes.runc = {
                  runtime_type = "io.containerd.runc.v2";
                };
              }
              (lib.mkIf hasNvidia {
                runtimes.nvidia = {
                  priviledged_without_host_devices = false;
                  runtime_type = "io.containerd.runc.v2"; 
                  options = {
                    BinaryName = "${pkgs.nvidia-container-toolkit.tools}/bin/nvidia-container-runtime";
                  };
                };
              })
            ];
          }
          (lib.mkIf hasNvidia {
            enable_cdi = true;
            cdi_spec_dirs = [ "/var/run/cdi" ];
          })
        ];
      };
    };
  };

  security.pam.loginLimits = [
    {domain = "*"; item = "memlock"; type = "-"; value = "unlimited";}
  ];
}

