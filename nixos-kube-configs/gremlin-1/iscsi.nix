{ config, pkgs, ... }:
{
  services.openiscsi = {
    discoverPortal = "10.1.1.2:3260";
    enable = true;
    name = "${config.networking.hostName}-initiatorhost";
  };
  services.target.enable = true;
}
