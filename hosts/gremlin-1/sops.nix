{ config, pkgs, lib, ... }:

{
  # SOPS configuration
  sops = {
    defaultSopsFile = ../../secrets/exo.yaml;
    age.keyFile = "/root/.config/sops/age/keys.txt";
    
    secrets.hf_token = {
      mode = "0440";
      owner = "root";
      group = "root";
    };
  };

  # Add HF_TOKEN to exo service environment
  # Create a wrapper script that sources the secret
  systemd.services.exo = {
    serviceConfig = {
      ExecStartPre = lib.mkBefore [
        "+${pkgs.writeShellScript "setup-hf-token" ''
          echo "HF_TOKEN=$(cat ${config.sops.secrets.hf_token.path})" > /run/exo-hf-token.env
          chmod 600 /run/exo-hf-token.env
        ''}"
      ];
      EnvironmentFile = lib.mkAfter [ "/run/exo-hf-token.env" ];
    };
  };
}
