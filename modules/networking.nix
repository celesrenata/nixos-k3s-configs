{ ... }:
{
  # DNS Configuration
  networking.nameservers = [ "192.168.42.1" "1.1.1.1" ];
  networking.useDHCP = false;
  
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
          LACPTransmitRate = "fast";
          TransmitHashPolicy = "layer3+4";
        };
      };
    };
    # Configure Bonds to utilize both 2.5Gbps ports
    networks = {
      "30-eth0" = {
        matchConfig.Name = "enp17*";
        networkConfig = {
          Bond = "bond0";
          DHCP = "no";
        };
        linkConfig.RequiredForOnline = "enslaved";
      };
      
      "40-bond0" = {
        matchConfig.Name = "bond0";
        networkConfig.DHCP = "no";
        linkConfig.RequiredForOnline = "routable";
      };
    };
  };
  services.rpcbind.enable = true;
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "yes";
  networking.firewall.enable = false;
}
