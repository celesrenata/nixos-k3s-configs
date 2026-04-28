{ config, pkgs, lib, ... }:

{
  sops = {
    defaultSopsFile = ../../secrets/exo.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets.hf_token = {
      mode = "0440";
      owner = "root";
      group = "root";
    };
    secrets.frp_auth_token = {};
    secrets.harp_shared_key = {};
  };
}
