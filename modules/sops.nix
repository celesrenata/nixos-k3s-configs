{ config, ... }:
{
  sops = {
    defaultSopsFile = ../secrets/exo.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets.k3s_token = {};
    secrets.harp_shared_key = {};
    secrets.harp_shared_key_uti = {};
    secrets.frp_auth_token = {};
  };
}
