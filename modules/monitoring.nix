{ pkgs, ... }:
{
  security.wrappers.perf = {
    owner = "root";
    group = "root";
    capabilities = "cap_perfmon=+ep";
    source = "${pkgs.perf}/bin/perf";
  };

  environment.systemPackages = [ pkgs.perf ];

  systemd.services.telegraf.serviceConfig.EnvironmentFile =
    "/etc/nixos/.config/PasswordFiles/influx.env";

  services.telegraf = {
    enable = true;
    extraConfig = {
      inputs.exec = {
        commands = [ "/etc/nixos/scripts/intel-gpu-stats.sh" ];
        interval = "10s";
        timeout = "10s";
        data_format = "influx";
      };

      outputs.influxdb_v2 = {
        urls = [ "http://10.1.1.12:8086" ];
        organization = "celestium.life";
        bucket = "influx";
        token = "$INFLUX_TOKEN";
      };
    };
  };
}

