{ config, lib, pkgs, ... }:
{
  # System Packages
  environment.systemPackages = with pkgs; [
    docker
    runc
    k3s 
    kubernetes-helm
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
  systemd.services = {
    nvidia-container-toolkit-cdi-generator = {
      # Even with `--library-search-path`, `nvidia-ctk` won't find the libs
      # unless I bodge their path into the environment.
      environment.LD_LIBRARY_PATH = "${config.hardware.nvidia.package}/lib";
    };
    k3s-containerd-setup = {
      # `virtualisation.containerd.settings` has no effect on k3s' bundled containerd.
      serviceConfig.Type = "oneshot";
      requiredBy = ["k3s.service"];
      before = ["k3s.service"];
      script = ''
        mkdir -p /var/lib/rancher/k3s/agent/etc/containerd
        cat << EOF > /var/lib/rancher/k3s/agent/etc/containerd/config.toml.tmpl
        {{ template "base" . }}
        version = 2
        
        [plugins]
        
          [plugins."io.containerd.grpc.v1.cri"]
        
            [plugins."io.containerd.grpc.v1.cri".containerd]
        
              [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
        
                [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia]
                  privileged_without_host_devices = false
                  runtime_engine = ""
                  runtime_root = ""
                  runtime_type = "io.containerd.runc.v2"
        
                  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia.options]
                    BinaryName = "/run/current-system/sw/bin/nvidia-container-runtime.cdi"
        EOF
      '';
    };
  };
  hardware.nvidia-container-toolkit.enable = true;

  hardware.nvidia-container-toolkit.mount-nvidia-executables = true; 
  #virtualisation.docker = {
  #  enable = true;
  #  enableNvidia = true;
  #};
  
  virtualisation = {
    docker = {
      enable = true;
      package = pkgs.docker_26;
      enableNvidia = true;
    };
  };
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
        plugins."io.containerd.grpc.v1.cri".containerd = {
          default_runtime_name = "nvidia";
          runtimes.runc = {
            runtime_type = "io.containerd.runc.v2";
          };
          runtimes.nvidia = {
            priviledged_without_host_devices = false;
            runtime_type = "io.containerd.runc.v2"; 
            options = {
              BinaryName = "/run/current-system/sw/bin/nvidia-container-runtime";
            };
          };
        };
        plugins."io.containerd.grpc.v1.cri" = {
          enable_cdi = true;
          cdi_spec_dirs = [ "/var/run/cdi" ];
        };
    };
  };
  security.pam.loginLimits = [
    {domain = "*"; item = "memlock"; type = "-"; value = "unlimited";}
  ];
}
