{ pkgs, ... }:

{
  boot.kernelModules = [ "siw" ];

  systemd.services.rdma-siw = {
    description = "RDMA SIW device on bond0";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.iproute2}/bin/rdma link show siw0 2>/dev/null || ${pkgs.iproute2}/bin/rdma link add siw0 type siw netdev bond0'";
      ExecStop = "${pkgs.iproute2}/bin/rdma link del siw0";
    };
  };

  environment.systemPackages = [ pkgs.rdma-core ];
}
