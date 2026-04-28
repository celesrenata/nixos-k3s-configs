{ config, pkgs, lib, ... }:
let
  isGremlin1 = config.networking.hostName == "gremlin-1";
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
      runtimes = {
        nvidia = {
          path = "nvidia-container-runtime";
          runtimeArgs = [];
        };
      };
    };
  };
  
  hardware.nvidia-container-toolkit.enable = lib.mkIf isGremlin1 true;
  
  environment.systemPackages = lib.mkIf isGremlin1 (with pkgs; [
    nvidia-container-toolkit
  ]);
  
  # Fix Docker service PATH to use dynamic store paths
  systemd.services.docker = lib.mkIf isGremlin1 {
    environment.PATH = pkgs.lib.mkForce "${pkgs.nvidia-container-toolkit.tools}/bin:${pkgs.lib.makeBinPath (with pkgs; [ kmod coreutils findutils gnugrep gnused systemd ])}";
  };

  # HARP for Nextcloud ExApps - only on gremlin-1
  services.frp = lib.mkIf isGremlin1 {
    enable = true;
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
  systemd.services.frp = lib.mkIf isGremlin1 {
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

  # HARP env file via sops template
  sops.templates."harp.env" = lib.mkIf isGremlin1 {
    content = ''
      HP_SHARED_KEY=${config.sops.placeholder.harp_shared_key}
    '';
  };

  # HARP Agent for ExApp management - only on gremlin-1
  systemd.services.harp-agent = lib.mkIf isGremlin1 {
    description = "HARP Agent for Nextcloud ExApps";
    after = [ "docker.service" "frp.service" ];
    wants = [ "docker.service" "frp.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      EnvironmentFile = config.sops.templates."harp.env".path;
      ExecStart = "${pkgs.docker}/bin/docker run --rm --name harp-agent -e HP_SHARED_KEY -e NC_INSTANCE_URL=https://nextcloud.celestium.life -p 8780:8780 -p 8782:8782 -v /var/run/docker.sock:/var/run/docker.sock ghcr.io/nextcloud/nextcloud-appapi-harp:release";
      Restart = "always";
      RestartSec = "10";
    };
  };
  networking.firewall.allowedTCPPorts = lib.mkIf isGremlin1 [ 7000 7500 24000 ];

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
  systemd.tmpfiles.rules = [
    "d /usr/share/kvm 0755 root root -"
    "C+ /usr/share/kvm/intelgopdriver_desktop.bin - - - - /etc/nixos/intelgopdriver_desktop.bin"
  ];
}
