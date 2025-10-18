{ pkgs, ... }:
{
  security.wrappers.nvtop = {
    owner = "root";
    group = "root";
    capabilities = "cap_perfmon=+ep";
    source = "${pkgs.nvtopPackages.intel}/bin/nvtop";
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
    extraFlags = [ "--web.telemetry-path=/metrics" "--web.exporter-telemetry-path=/exporter_metrics" ];
   
  };

  services.telegraf = {
    enable = true;
    extraConfig = {
      inputs = {
        exec = {
          name_override = "nvtop_intel";
          commands = [ "/run/current-system/sw/bin/timeout --preserve-status -s SIGINT -k 2 2 /run/wrappers/bin/nvtop -s" ];
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
