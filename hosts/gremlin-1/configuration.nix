{ config, pkgs, systemHostname, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # System-specific networking
  networking.hostName = systemHostname;
  systemd.network = {
    networks = {
      "40-bond0" = {
        matchConfig.Name = "bond0";
        linkConfig = {
          RequiredForOnline = "routable";
        };
        address = [ "10.1.1.12/24" ];
        gateway = [ "10.1.1.1" ];
      };
    };
  };

  # InfluxDB service with provisioning
  services.influxdb2 = {
    enable = true;
    provision = {
      enable = true;
      initialSetup = {
        organization = "celestium.life";
        bucket = "influx";
        username = "admin";
        passwordFile = "/etc/nixos/.config/PasswordFiles/influx.pass";
        tokenFile = "/etc/nixos/.config/PasswordFiles/influx.token";
      };
    };
  };
}
    ./../../modules/frp-config.nix
