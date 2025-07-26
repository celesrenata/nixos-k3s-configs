{ config, pkgs, systemHostname, ... }:

{
  imports = [
    ../../hardware-configuration.nix  # You'll need to create this for gremlin-4
  ];

  # System-specific networking (assuming next IP in sequence)
  networking.hostName = systemHostname;
  systemd.network = {
    networks = {
      "40-bond0" = {
        matchConfig.Name = "bond0";
        linkConfig = {
          RequiredForOnline = "routable";
        };
        address = [ "10.1.1.15/24" ];  # Next IP in sequence
        gateway = [ "10.1.1.1" ];
      };
    };
  };
}
