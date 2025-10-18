{ pkgs, ... }:
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
  virtualisation.docker = {
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
  hardware.nvidia-container-toolkit.enable = true;
  environment.systemPackages = with pkgs; [
    nvidia-container-toolkit
  ];
  # Add the actual tools package to Docker service PATH
  systemd.services.docker.environment.PATH = pkgs.lib.mkForce "/nix/store/inl3a1m3hi9mn3lxz6cj12lcjkcv4c6z-nvidia-container-toolkit-1.17.8-tools/bin:${pkgs.lib.makeBinPath (with pkgs; [ kmod coreutils findutils gnugrep gnused systemd ])}";

  # HARP for Nextcloud ExApps
  services.frp.enable = true;
  services.frp.role = "server";
  services.frp.settings = {
    bindPort = 7000;
    auth.token = "8d8ec4a34b65ca090e99edbefd2fa72c9fd689c563de9a74ce11c7d39887d583";
    webServer = {
      addr = "0.0.0.0";
      port = 7500;
    };
  };
  
  # Open firewall ports for HARP and Docker API
  networking.firewall.allowedTCPPorts = [ 7000 7500 24000 2375 ];
}
