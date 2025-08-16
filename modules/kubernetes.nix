{ config, lib, pkgs, hasNvidia ? false, ... }:
let
  # buildEnv that bundles flannel + the full CNI plugin set (bridge, host-local, vlan, etc)
  fullCNIPlugins = pkgs.buildEnv {
    name = "cni-full";
    paths = with pkgs; [
      cni-plugin-flannel  # your primary CNI for pod networking
      multus-cni          # Multus CNI for multiple network interfaces
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
    libnvidia-container  # Provides nvidia-container-cli
  ];

  # Kubernetes Service - conditional configuration based on hostname
  services.k3s = {
    enable = true;
    role = "server";
    token = "532a3cf6ea";
    # Only gremlin-1 initializes the cluster, others join it
    clusterInit = (config.networking.hostName == "gremlin-1");
    # Non-leader servers need to know where to connect
    serverAddr = lib.mkIf (config.networking.hostName != "gremlin-1") "https://10.1.1.12:6443";
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
                BinaryName = "${pkgs.nvidia-container-toolkit.tools}/bin/nvidia-container-runtime"
                SystemdCgroup = true

              [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia.env]
                PATH = "${pkgs.nvidia-container-toolkit.tools}/bin:${pkgs.libnvidia-container}/bin:/run/current-system/sw/bin"

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
      # Ensure CDI directory exists
      nvidia-cdi-setup = {
        description = "Setup NVIDIA CDI directory";
        wantedBy = [ "multi-user.target" ];
        before = [ "nvidia-container-toolkit.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.coreutils}/bin/mkdir -p /var/run/cdi";
        };
      };

      # Create symlinks for nvidia-container-cli in standard locations
      nvidia-container-cli-setup = {
        description = "Setup NVIDIA container CLI symlinks";
        wantedBy = [ "multi-user.target" ];
        before = [ "k3s.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = [
            "${pkgs.coreutils}/bin/mkdir -p /usr/bin"
            "${pkgs.coreutils}/bin/ln -sf ${pkgs.libnvidia-container}/bin/nvidia-container-cli /usr/bin/nvidia-container-cli"
          ];
        };
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
                    SystemdCgroup = true;
                  };
                  env = [
                    "PATH=${pkgs.nvidia-container-toolkit.tools}/bin:${pkgs.libnvidia-container}/bin:/run/current-system/sw/bin"
                  ];
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

  # Ensure nvidia-container-cli and related tools are in PATH for NVIDIA nodes
  environment.variables = lib.mkIf hasNvidia {
    PATH = lib.mkAfter [ 
      "${pkgs.nvidia-container-toolkit.tools}/bin" 
      "${pkgs.libnvidia-container}/bin"
    ];
  };

  security.pam.loginLimits = [
    {domain = "*"; item = "memlock"; type = "-"; value = "unlimited";}
  ];
}

