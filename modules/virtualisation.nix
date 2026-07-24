{ config, pkgs, lib, ... }:
let
  isGremlin1 = config.networking.hostName == "gremlin-1";
  nvidiaContainerRuntimeConfig = ''
    disable-require = false
    supported-driver-capabilities = "compat32,compute,display,graphics,ngx,utility,video"

    [nvidia-container-cli]
    environment = ["LD_LIBRARY_PATH=/run/opengl-driver/lib"]
    path = "/etc/nvidia-container-runtime/cli-wrapper.sh"
    root = "/usr/local/nvidia"
    ldconfig = "@/sbin/ldconfig"
    load-kmods = true
    no-cgroups = true

    [nvidia-container-runtime]
    log-level = "info"
    mode = "cdi"
    runtimes = ["runc", "crun"]

    [nvidia-container-runtime.modes]

    [nvidia-container-runtime.modes.cdi]
    annotation-prefixes = ["cdi.k8s.io/"]
    default-kind = "nvidia.com/gpu"
    spec-dirs = ["/etc/cdi", "/var/run/cdi"]

    [nvidia-container-runtime.modes.csv]
    mount-spec-path = "/etc/nvidia-container-runtime/host-files-for-container.d"

    [nvidia-container-runtime.modes.legacy]
    cuda-compat-mode = "ldconfig"

    [nvidia-container-runtime-hook]
    path = "/usr/bin/nvidia-container-runtime-hook"
    skip-mode-detection = false

    [nvidia-ctk]
    path = "/usr/bin/nvidia-ctk"
  '';

  # Wrapper script that sets LD_LIBRARY_PATH so nvidia-container-cli can find libnvidia-ml
  nvidiaCliWrapper = pkgs.writeShellScriptBin "nvidia-container-cli" ''
    export LD_LIBRARY_PATH=/usr/local/nvidia/lib64:''${LD_LIBRARY_PATH:-}
    exec /usr/bin/nvidia-container-cli "$@"
  '';
in
{
  # Virtualization
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = true;
      swtpm.enable = true;
    };
  };
  programs.virt-manager.enable = true;
  
  # Docker only on gremlin-1
  virtualisation.docker = lib.mkIf isGremlin1 {
    enable = true;
    storageDriver = "btrfs";
    listenOptions = [ "/var/run/docker.sock" "127.0.0.1:2375" ];
    daemon.settings = {
      default-runtime = "runc";
      features = { cdi = lib.mkForce true; };
      runtimes = {
        nvidia = {
          path = "${pkgs.nvidia-container-toolkit.tools}/bin/nvidia-container-runtime";
          runtimeArgs = [];
        };
      };
    };
  };
  
  hardware.nvidia-container-toolkit.enable = lib.mkIf isGremlin1 true;
  
  environment.systemPackages = lib.mkIf isGremlin1 (with pkgs; [
    nvidia-container-toolkit
  ]);

  # nvidia-container-runtime config.toml for Docker DeviceRequests support
  environment.etc."nvidia-container-runtime/config.toml" = lib.mkIf isGremlin1 {
    text = nvidiaContainerRuntimeConfig;
  };

  # Symlinks and wrapper for nvidia-container-cli (legacy mode needs LD_LIBRARY_PATH)
  systemd.tmpfiles.rules = [
    "d /usr/share/kvm 0755 root root -"
    "C+ /usr/share/kvm/intelgopdriver_desktop.bin - - - - /etc/nixos/intelgopdriver_desktop.bin"
  ] ++ lib.optionals isGremlin1 [
    "L+ /sbin/ldconfig - - - - /run/current-system/sw/bin/ldconfig"
    "d /usr/local/bin 0755 root root -"
    "L+ /usr/local/bin/nvidia-container-cli - - - - ${nvidiaCliWrapper}/bin/nvidia-container-cli"
  ];

  # HARP for Nextcloud ExApps - only on gremlin-1
  services.frp.instances.harp = lib.mkIf isGremlin1 {
    role = "server";
    settings = {
      bindPort = 7000;
      auth.token = "PLACEHOLDER";
      webServer = {
        addr = "0.0.0.0";
        port = 7500;
      };
    };
  };

  # Override frp config with sops template containing the real token
  systemd.services.frp-harp = lib.mkIf isGremlin1 {
    serviceConfig.ExecStart = lib.mkForce "${pkgs.frp}/bin/frps --strict_config -c ${config.sops.templates."frp.toml".path}";
  };

  sops.templates."frp.toml" = lib.mkIf isGremlin1 {
    mode = "0444";
    content = ''
      bindPort = 7000

      [auth]
      token = "${config.sops.placeholder.frp_auth_token}"

      [webServer]
      addr = "0.0.0.0"
      port = 7500
    '';
  };

  # HARP env file via sops template (celestium nextcloud)
  sops.templates."harp.env" = lib.mkIf isGremlin1 {
    content = ''
      HP_SHARED_KEY=${config.sops.placeholder.harp_shared_key}
    '';
  };

  # HARP env file via sops template (uti nextcloud)
  sops.templates."harp-uti.env" = lib.mkIf isGremlin1 {
    content = ''
      HP_SHARED_KEY=${config.sops.placeholder.harp_shared_key_uti}
    '';
  };

  # HARP Agent for ExApp management (nextcloud.celestium.life) - only on gremlin-1
  systemd.services.harp-agent = lib.mkIf isGremlin1 {
    description = "HARP Agent for Nextcloud ExApps";
    after = [ "docker.service" "frp-harp.service" "docker-gpu-proxy.service" ];
    wants = [ "docker.service" "frp-harp.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      EnvironmentFile = config.sops.templates."harp.env".path;
      ExecStart = "${pkgs.docker}/bin/docker run --rm --name harp-agent -e HP_SHARED_KEY -e NC_INSTANCE_URL=https://nextcloud.celestium.life -p 8780:8780 -p 8782:8782 -v /var/run/docker-gpu.sock:/var/run/docker.sock ghcr.io/nextcloud/nextcloud-appapi-harp:release";
      Restart = "always";
      RestartSec = "10";
    };
  };

  # HARP Agent for ExApp management (uti.celestium.life) - only on gremlin-1
  systemd.services.harp-agent-uti = lib.mkIf isGremlin1 {
    description = "HARP Agent for UTI Nextcloud ExApps";
    after = [ "docker.service" "frp-harp.service" "docker-gpu-proxy.service" ];
    wants = [ "docker.service" "frp-harp.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      EnvironmentFile = config.sops.templates."harp-uti.env".path;
      ExecStart = "${pkgs.docker}/bin/docker run --rm --name harp-agent-uti -e HP_SHARED_KEY -e NC_INSTANCE_URL=https://uti.celestium.life -p 8790:8780 -p 8792:8782 -v /var/run/docker-gpu.sock:/var/run/docker.sock ghcr.io/nextcloud/nextcloud-appapi-harp:release";
      Restart = "always";
      RestartSec = "10";
    };
  };

  # Docker GPU proxy - rewrites legacy DeviceRequests to CDI format for NixOS
  systemd.services.docker-gpu-proxy = lib.mkIf isGremlin1 {
    description = "Docker GPU Socket Proxy (DeviceRequests to CDI rewriter)";
    after = [ "docker.service" ];
    wants = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 /etc/nvidia-container-runtime/docker-gpu-proxy.py";
      Restart = "always";
      RestartSec = "5";
    };
  };

  networking.firewall.allowedTCPPorts = lib.mkIf isGremlin1 [ 7000 7500 24000 8790 8792 ];

  # Registry mirror: try Harbor proxy cache first, fall back to Docker Hub
  environment.etc."containerd/certs.d/docker.io/hosts.toml".text = ''
server = "https://registry-1.docker.io"

[host."https://registry.celestium.life/v2/dockerhub-cache"]
  capabilities = ["pull", "resolve"]
  dial_timeout = "3s"
  response_header_timeout = "3s"
  override_path = true

[host."https://registry-1.docker.io"]
  capabilities = ["pull", "resolve"]
  '';

  # Intel GPU ROM file for SR-IOV passthrough
}
