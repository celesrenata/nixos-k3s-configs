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
  # k3s registries config - trust system CA for SSL bump
  environment.etc."rancher/k3s/registries.yaml".text = ''
    mirrors:
      docker.io:
        endpoint:
          - "https://registry-1.docker.io"
    configs:
      "registry-1.docker.io":
        tls:
          ca_file: /etc/ssl/certs/ca-certificates.crt
  '';

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
    extraFlags = let
      bondAddr = builtins.head config.systemd.network.networks."40-bond0".address;
      nodeIp = lib.removeSuffix "/24" bondAddr;
    in (toString [
      "--container-runtime-endpoint unix:///run/containerd/containerd.sock"
      "--node-ip ${nodeIp}"
      "--flannel-iface bond0"
    ]); 
  };

  systemd.services = lib.mkMerge [
    # Proxy and SSL configuration for container image pulls
    {
      k3s.environment = {
        # HTTP_PROXY = "http://192.168.42.1:3128"; # disabled - SSL filtering off
        #         HTTPS_PROXY = "http://192.168.42.1:3128";
        #         NO_PROXY = "10.0.0.0/8,192.168.0.0/16,127.0.0.1,localhost,.svc,.cluster.local,.celestium.life";
        SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
      };
      containerd.environment = {
        # HTTP_PROXY = "http://192.168.42.1:3128"; # disabled - SSL filtering off
        #         HTTPS_PROXY = "http://192.168.42.1:3128";
        #         NO_PROXY = "10.0.0.0/8,192.168.0.0/16,127.0.0.1,localhost,.svc,.cluster.local,.celestium.life";
        SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
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
      # Disable the NixOS-provided CDI generator — it fails on NixOS without --dev-root=/
      # Our nvidia-cdi-setup service handles CDI spec generation correctly.
      nvidia-container-toolkit-cdi-generator.enable = false;

      # Ensure CDI directory exists and generate CDI specs
      # Waits for /dev/nvidia0 to appear before generating, with retries
      nvidia-cdi-setup = {
        description = "Setup NVIDIA CDI directory and generate specs";
        wantedBy = [ "multi-user.target" ];
        after = [ "nvidia-persistenced.service" "systemd-udev-settle.service" ];
        requires = [ "nvidia-persistenced.service" ];
        before = [ "k3s.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeShellScript "nvidia-cdi-setup" ''
            set -euo pipefail

            # Wait for GPU device nodes (up to 120s)
            for i in $(seq 1 60); do
              if [ -e /dev/nvidia0 ] && [ -e /dev/nvidiactl ]; then
                echo "GPU device nodes ready after $((i*2))s"
                break
              fi
              if [ "$i" -eq 60 ]; then
                echo "ERROR: /dev/nvidia0 not found after 120s, aborting"
                exit 1
              fi
              sleep 2
            done

            # Extra settle time for driver initialization
            sleep 2

            mkdir -p /var/run/cdi /etc/nvidia-container-runtime/host-files-for-container.d

            cat > /etc/nvidia-container-runtime/host-files-for-container.d/binaries.csv << EOF
bin,${config.hardware.nvidia.package.bin}/bin/nvidia-smi
lib,${pkgs.glibc}/lib/ld-linux-x86-64.so.2
EOF

            # Generate CDI spec with index naming (gives "0" and "all" devices)
            ${pkgs.nvidia-container-toolkit}/bin/nvidia-ctk cdi generate \
              --format=json \
              --mode=nvml \
              --driver-root=/ \
              --dev-root=/ \
              --device-name-strategy=index \
              --disable-hook create-symlinks \
              --library-search-path=${config.hardware.nvidia.package}/lib \
              --ldconfig-path=${pkgs.glibc.bin}/bin/ldconfig \
              --nvidia-cdi-hook-path=${pkgs.nvidia-container-toolkit.tools}/bin/nvidia-cdi-hook \
              --output=/var/run/cdi/nvidia-container-toolkit.json

            # Add GPU UUID device name so pods requesting by UUID also work
            GPU_UUID=$(${pkgs.nvidia-container-toolkit}/bin/nvidia-ctk cdi generate \
              --format=json --mode=nvml --driver-root=/ --dev-root=/ \
              --device-name-strategy=uuid \
              --library-search-path=${config.hardware.nvidia.package}/lib \
              --ldconfig-path=${pkgs.glibc.bin}/bin/ldconfig \
              --nvidia-cdi-hook-path=${pkgs.nvidia-container-toolkit.tools}/bin/nvidia-cdi-hook \
              2>/dev/null | ${pkgs.jq}/bin/jq -r '.devices[0].name')
            if [ -n "$GPU_UUID" ] && [ "$GPU_UUID" != "null" ]; then
              ${pkgs.jq}/bin/jq --arg uuid "$GPU_UUID" \
                '.devices += [{"name": $uuid, "containerEdits": .devices[0].containerEdits}]' \
                /var/run/cdi/nvidia-container-toolkit.json > /tmp/cdi-merged.json
              cp /tmp/cdi-merged.json /var/run/cdi/nvidia-container-toolkit.json
            fi

            echo "CDI spec generated successfully"
          '';
        };
      };

      # Clean up stale pods after reboot (Unknown/UnexpectedAdmissionError)
      k3s-gpu-pod-cleanup = {
        description = "Clean up stale GPU pods after reboot";
        wantedBy = [ "multi-user.target" ];
        after = [ "k3s.service" "nvidia-cdi-setup.service" ];
        requires = [ "k3s.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeShellScript "k3s-gpu-pod-cleanup" ''
            export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
            export PATH=${pkgs.k3s}/bin:$PATH

            # Wait for k3s API to be ready (up to 120s)
            for i in $(seq 1 60); do
              if kubectl get nodes &>/dev/null; then
                break
              fi
              sleep 2
            done

            # Give pods time to settle into their final state
            sleep 15

            # Delete pods stuck in Unknown (orphaned from pre-reboot)
            for ns_pod in $(kubectl get pods --all-namespaces --field-selector=status.phase=Unknown -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}' 2>/dev/null); do
              ns="''${ns_pod%%/*}"
              pod="''${ns_pod##*/}"
              echo "Deleting Unknown pod: $ns/$pod"
              kubectl delete pod -n "$ns" "$pod" --force --grace-period=0 2>/dev/null || true
            done

            # Delete pods with UnexpectedAdmissionError
            for ns_pod in $(kubectl get pods --all-namespaces -o jsonpath='{range .items[?(@.status.reason=="UnexpectedAdmissionError")]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}' 2>/dev/null); do
              ns="''${ns_pod%%/*}"
              pod="''${ns_pod##*/}"
              echo "Deleting UnexpectedAdmissionError pod: $ns/$pod"
              kubectl delete pod -n "$ns" "$pod" --force --grace-period=0 2>/dev/null || true
            done

            echo "Pod cleanup complete"
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
