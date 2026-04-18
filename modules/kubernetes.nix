{ config, lib, pkgs, ... }:
let
  cfg = config.gremlin.graphics;
  hasNvidia = cfg.nvidia.enable;
  hasIntel = cfg.intel.enable;
  
  # Static video group GID (matches common.nix)
  videoGid = 500;
  
  # Intel GPU container runtime - add video group access
  intel-gpu-runc = pkgs.writeShellScriptBin "intel-gpu-runc" ''
    if [ "$1" = "create" ] || [ "$1" = "run" ]; then
        exec ${pkgs.runc}/bin/runc "$@" --additional-gids "${toString videoGid}"
    else
        exec ${pkgs.runc}/bin/runc "$@"
    fi
  '';
  
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
    runc
    k3s 
    kubernetes-helm
  ] ++ lib.optionals hasNvidia [
    nvidia-container-toolkit
    libnvidia-container  # Provides nvidia-container-cli
  ] ++ lib.optionals hasIntel [
    libva-utils
    intel-gpu-tools
    intel-gpu-runc
  ];

  # Static video group for Intel GPU containers - create it properly
  users.groups = lib.mkIf hasIntel {
    video.gid = videoGid;
  };

  # Kubernetes Service - conditional configuration based on hostname
  services.k3s = {
    enable = true;
    role = "server";
    token = "532a3cf6ea";
    # Only gremlin-4 initializes the cluster, others join it
    clusterInit = (config.networking.hostName == "gremlin-4");
    # Non-leader servers need to know where to connect
    serverAddr = lib.mkIf (config.networking.hostName != "gremlin-4") "https://10.1.1.15:6443";
    extraFlags = (toString [
      "--container-runtime-endpoint unix:///run/containerd/containerd.sock"
    ]); 
  };

  systemd.services = lib.mkMerge [
    # Proxy configuration for container image pulls
    {
      k3s.environment = {
        HTTP_PROXY = "http://192.168.42.1:3128";
        HTTPS_PROXY = "http://192.168.42.1:3128";
        NO_PROXY = "10.0.0.0/8,192.168.0.0/16,127.0.0.1,localhost,.svc,.cluster.local";
      };
    }
    {
      k3s-containerd-setup = {
        serviceConfig.Type = "oneshot";
        requiredBy = ["k3s.service"];
        before = ["k3s.service"];
        script = ''
          mkdir -p /var/lib/rancher/k3s/agent/etc/containerd
          cat << EOF > /var/lib/rancher/k3s/agent/etc/containerd/config.toml.tmpl
          {{ template "base" . }}
          version = 2

          [plugins."io.containerd.grpc.v1.cri".cni]
            bin_dir  = "${fullCNIPlugins}/bin"
            conf_dir = "/var/lib/rancher/k3s/agent/etc/cni/net.d"

          [plugins."io.containerd.grpc.v1.cri".containerd]
            default_runtime_name = "${if hasNvidia then "nvidia" else "runc"}"

            [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
              runtime_type = "io.containerd.runc.v2"

            [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.intel-gpu]
              runtime_type = "io.containerd.runc.v2"
              
              [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.intel-gpu.options]
                BinaryName = "${intel-gpu-runc}/bin/intel-gpu-runc"
                SystemdCgroup = true

          ${lib.optionalString hasNvidia ''
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
          ''}
          EOF
        '';
      };
    }
    (lib.mkIf hasNvidia {
      # Ensure CDI directory exists and generate CDI specs
      nvidia-cdi-setup = {
        description = "Setup NVIDIA CDI directory and generate specs";
        wantedBy = [ "multi-user.target" ];
        after = [ "nvidia-persistenced.service" ];
        requires = [ "nvidia-persistenced.service" ];
        before = [ "k3s.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeShellScript "nvidia-cdi-setup" ''
            mkdir -p /var/run/cdi /etc/nvidia-container-runtime/host-files-for-container.d
            
            # Create CSV for binaries and glibc - NO SPACE after comma
            cat > /etc/nvidia-container-runtime/host-files-for-container.d/binaries.csv << EOF
bin,${config.hardware.nvidia.package.bin}/bin/nvidia-smi
lib,${pkgs.glibc}/lib/ld-linux-x86-64.so.2
EOF
            
            ${pkgs.nvidia-container-toolkit}/bin/nvidia-ctk cdi generate \
              --mode=nvml \
              --driver-root=/ \
              --library-search-path=${config.hardware.nvidia.package}/lib \
              --csv.file=/etc/nvidia-container-runtime/host-files-for-container.d/binaries.csv \
              --output=/var/run/cdi/nvidia.yaml
            
            # Fix all symlinks - resolve /run/current-system and /run/opengl-driver to actual Nix store paths
            ${pkgs.gnused}/bin/sed -i \
              -e 's|/run/current-system/sw/bin/nvidia-smi|${config.hardware.nvidia.package.bin}/bin/nvidia-smi|g' \
              -e 's|/run/opengl-driver/lib|${config.hardware.nvidia.package}/lib|g' \
              /var/run/cdi/nvidia.yaml
          '';
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
            "${pkgs.coreutils}/bin/ln -sf ${pkgs.nvidia-container-toolkit.tools}/bin/nvidia-cdi-hook /usr/bin/nvidia-cdi-hook"
            "${pkgs.coreutils}/bin/ln -sf ${pkgs.nvidia-container-toolkit}/bin/nvidia-ctk /usr/bin/nvidia-ctk"
          ];
        };
      };

      # Copy NVIDIA libraries to standard paths for device plugin
      nvidia-lib-setup = {
        description = "Setup NVIDIA libraries in standard paths";
        wantedBy = [ "multi-user.target" ];
        before = [ "k3s.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeShellScript "nvidia-lib-setup" ''
            mkdir -p /usr/local/nvidia/lib64
            cp -Lf ${config.hardware.nvidia.package}/lib/libnvidia-ml.so* /usr/local/nvidia/lib64/ || true
            chmod 755 /usr/local/nvidia/lib64/*
          '';
        };
      };
    })
    (lib.mkIf hasIntel {
      # Setup Intel GPU environment and device permissions
      intel-gpu-setup = {
        description = "Setup Intel GPU environment for containers";
        wantedBy = [ "multi-user.target" ];
        before = [ "k3s.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = [
            "${pkgs.coreutils}/bin/mkdir -p /var/run/intel-gpu"
            # Fix permissions for Intel GPU devices specifically
            "${pkgs.coreutils}/bin/chmod 666 /dev/dri/renderD128"
            "${pkgs.coreutils}/bin/chgrp video /dev/dri/renderD128"
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
              (lib.mkIf hasIntel {
                runtimes.intel-gpu = {
                  runtime_type = "io.containerd.runc.v2";
                  options = {
                    BinaryName = "${intel-gpu-runc}/bin/intel-gpu-runc";
                    SystemdCgroup = true;
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

  # Enhanced udev rules for Intel GPU
  services.udev.extraRules = lib.mkIf hasIntel ''
    # Intel GPU devices - specific to renderD128 (Intel Arc)
    SUBSYSTEM=="drm", KERNEL=="renderD128", GROUP="video", MODE="0666"
    SUBSYSTEM=="drm", KERNEL=="card0", ATTRS{vendor}=="0x8086", GROUP="video", MODE="0664"
  '';

  # Environment variables
  environment.variables = lib.mkMerge [
    (lib.mkIf hasNvidia {
      PATH = lib.mkAfter [ 
        "${pkgs.nvidia-container-toolkit.tools}/bin" 
        "${pkgs.libnvidia-container}/bin"
      ];
    })
    (lib.mkIf hasIntel {
      LIBVA_DRIVER_NAME = "iHD";
      LIBVA_DRIVERS_PATH = "${pkgs.intel-media-driver}/lib/dri";
    })
  ];

  security.pam.loginLimits = [
    {domain = "*"; item = "memlock"; type = "-"; value = "unlimited";}
  ];
}
