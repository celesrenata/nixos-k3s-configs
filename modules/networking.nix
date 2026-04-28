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
        networkConfig.DNS = [ "192.168.42.1" "1.1.1.1" ];
        networkConfig.Domains = [ "~celestium.life" ];
        linkConfig.RequiredForOnline = "routable";
      };
    };
  };
  services.rpcbind.enable = true;
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "prohibit-password";
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [
    22      # SSH
    6443    # K3s API
    2379    # etcd client
    2380    # etcd peer
    10250   # kubelet
    3493    # NUT UPS
    3632    # DistCC
    8086    # InfluxDB
    8472    # flannel VXLAN
    9100    # node-exporter
    10200   # Wyoming piper
    10300   # Wyoming whisper
  ];
  networking.firewall.allowedUDPPorts = [
    8472    # flannel VXLAN
  ];

  # Static resolv.conf for k3s CoreDNS (avoids systemd-resolved stub)
  environment.etc."k3s-resolv.conf".text = ''
    nameserver 192.168.42.1
    nameserver 1.1.1.1
  '';
}
