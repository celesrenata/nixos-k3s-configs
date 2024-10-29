{ pkgs, ... }:
{
  security.wrappers.intel_gpu_top = {
    owner = "root";
    group = "root";
    capabilities = "cap_perfmon=+ep";
    source = "${pkgs.intel-gpu-tools}/bin/intel_gpu_top";
  };

  services.prometheus.exporters.node = {
    enable = true;
    port = 9000;
    enabledCollectors = [ "systemd" ];
    extraFlags = [ "--collector.ethtool" "--collector.softirqs" "--collector.tcpstat" ];
  };

  services.prometheus.exporters.nut = {
    enable = true;
    nutServer = "127.0.0.1";
    nutUser = "nutmaster";
    passwordPath = "/etc/nixos/.config/PasswordFiles/apc.pass";
    extraFlags = [ "--web.telemetry-path=/ups" ];
  };

  services.telegraf = {
    enable = true;
    extraConfig = {
      inputs = {
        exec = {
          name_override = "intel_gpu_top";
          commands = [ "/run/current-system/sw/bin/timeout --preserve-status -s SIGINT -k 2 2 /run/wrappers/bin/intel_gpu_top -J -s 1000" ];
          json_query = "[:1]";
          timeout = "3s";
          data_format = "json";
          json_strict = false;
        };
      };
      outputs = {
        influxdb_v2 = {
          organization = "celestium.life";
          token = "GAOT4Gsjum2LmNo7L1D8Cm4MuFIcKDwd_AR2KMZNsePfIuytMmInZpTd6ijr-_ubAyXcnMZedtO7hARvbgjxGg=="; 
          bucket = "influx";
          urls = [
            "http://10.1.1.12:8086"
          ];
        };
      };
    };
  };
}
