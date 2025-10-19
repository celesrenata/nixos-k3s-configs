{ config, pkgs, ... }:

{
  services.frp = {
    enable = true;
    role = "server";
    settings = {
      bindPort = 8782;
      auth.token = "u8QS37zNm_KVXdsG-djbhw2BEGZOCeH44p3jK8NyjsA";
    };
  };

  networking.firewall.allowedTCPPorts = [ 8782 23000 24000 ];
}
