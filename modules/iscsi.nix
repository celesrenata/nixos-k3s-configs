{ config, pkgs, ... }:
{
  services.openiscsi = {
    enable = true;
    name = "${config.networking.hostName}-initiatorhost";
  };
  services.target.enable = true;
}
