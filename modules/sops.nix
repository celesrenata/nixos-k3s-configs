{ config, ... }:
{
  # SOPS secrets management
  sops.defaultSopsFile = ../secrets/exo.yaml;
  sops.age.keyFile = "/root/.config/sops/age/keys.txt";
  
  sops.secrets.hf_token = {
    mode = "0400";
    owner = "root";
  };
  
  # Make HF_TOKEN available to exo service
  systemd.services.exo = {
    environment = {
      HF_TOKEN = config.sops.secrets.hf_token.path;
    };
  };
}
