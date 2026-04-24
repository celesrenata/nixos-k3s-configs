{ pkgs, ... }:
let
  parser = pkgs.writeScript "intel-gpu-stats-parser" (builtins.readFile ../scripts/intel-gpu-stats-parser.py);
  intel-gpu-stats = pkgs.writeShellScript "intel-gpu-stats" ''
    ${pkgs.intel-gpu-tools}/bin/intel_gpu_top -J -s 1000 2>/dev/null | ${pkgs.python3}/bin/python3 ${parser}
  '';
in
{
  environment.systemPackages = [ pkgs.intel-gpu-tools ];

  users.users.telegraf.extraGroups = [ "video" ];

  systemd.services.telegraf.serviceConfig.AmbientCapabilities = [ "CAP_PERFMON" ];
  systemd.services.telegraf.serviceConfig.CapabilityBoundingSet = [ "CAP_PERFMON" ];

  services.telegraf = {
    enable = true;
    environmentFiles = [ "/etc/nixos/.config/PasswordFiles/influx.env" ];
    extraConfig = {
      inputs.exec = {
        commands = [ "${intel-gpu-stats}" ];
        interval = "10s";
        timeout = "10s";
        data_format = "influx";
      };

      outputs.influxdb_v2 = {
        urls = [ "http://10.1.1.12:8086" ];
        organization = "celestium.life";
        bucket = "influx";
        token = "\${INFLUX_TOKEN}";
      };
    };
  };
}
