{ config, ... }:
{
  sops = {
    defaultSopsFile = ../secrets/exo.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets.k3s_token = {};
  };
}
