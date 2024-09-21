{ ... }:
{
  # Networking
  systemd.network = {
    enable = true;
    netdevs = {
      "10-bond0" = {
        netdevConfig = {
          Kind = "bond";
          Name = "bond0";
        };
        bondConfig = {
          Mode = "802.3ad";
          TransmitHashPolicy = "layer3+4";
        };
      };
    };
    # Configure Bonds to utilize both 2.5Gbps ports
    networks = {
      "30-enp170s0" = {
        matchConfig.Name = "enp170s0";
        networkConfig.Bond = "bond0";
      };
  
      "30-enp171s0" = {
        matchConfig.Name = "enp171s0";
        networkConfig.Bond = "bond0";
      };
    };
  };
  services.rpcbind.enable = true;
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "yes";
  networking.firewall.enable = false;
}
