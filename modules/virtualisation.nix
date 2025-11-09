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
    listenOptions = [ "/var/run/docker.sock" "0.0.0.0:2375" ];
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
  
  # Add the actual tools package to Docker service PATH - only on gremlin-1
  systemd.services.docker = lib.mkIf isGremlin1 {
    environment.PATH = pkgs.lib.mkForce "/nix/store/inl3a1m3hi9mn3lxz6cj12lcjkcv4c6z-nvidia-container-toolkit-1.17.8-tools/bin:${pkgs.lib.makeBinPath (with pkgs; [ kmod coreutils findutils gnugrep gnused systemd ])}";
  };

  # HARP for Nextcloud ExApps - only on gremlin-1
  services.frp = lib.mkIf isGremlin1 {
    enable = true;
    role = "server";
    settings = {
      bindPort = 7000;
      auth.token = "8d8ec4a34b65ca090e99edbefd2fa72c9fd689c563de9a74ce11c7d39887d583";
      webServer = {
        addr = "0.0.0.0";
        port = 7500;
      };
    };
  };
  
  # Open firewall ports for HARP and Docker API - only on gremlin-1
  # HARP Agent for ExApp management - only on gremlin-1
  systemd.services.harp-agent = lib.mkIf isGremlin1 {
    description = "HARP Agent for Nextcloud ExApps";
    after = [ "docker.service" "frp.service" ];
    wants = [ "docker.service" "frp.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.docker}/bin/docker run --rm --name harp-agent -e HP_SHARED_KEY=8d8ec4a34b65ca090e99edbefd2fa72c9fd689c563de9a74ce11c7d39887d583 -e NC_INSTANCE_URL=https://nextcloud.celestium.life -p 8780:8780 -p 8782:8782 -v /var/run/docker.sock:/var/run/docker.sock ghcr.io/nextcloud/nextcloud-appapi-harp:release";
      Restart = "always";
      RestartSec = "10";
    };
  };
  networking.firewall.allowedTCPPorts = lib.mkIf isGremlin1 [ 7000 7500 24000 2375 ];
}

  # Intel GPU ROM file for SR-IOV passthrough
  systemd.tmpfiles.rules = [
    "d /usr/share/kvm 0755 root root -"
    "C /usr/share/kvm/intelgopdriver_desktop.bin - - - - /etc/nixos/intelgopdriver_desktop.bin"
  ];
