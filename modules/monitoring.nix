{ pkgs, ... }:
{
  security.wrappers.nvtop = {
    owner = "root";
    group = "root";
    capabilities = "cap_perfmon=+ep";
    source = "${pkgs.nvtopPackages.intel}/bin/nvtop";
  };

  environment.systemPackages = with pkgs; [
    (writeShellScriptBin "nvtop-numeric" ''
      /run/wrappers/bin/nvtop -s | ${pkgs.jq}/bin/jq '.[0] | {
        device_name: .device_name,
        gpu_clock_mhz: (if .gpu_clock then (.gpu_clock | gsub("MHz"; "") | tonumber) else 0 end),
        temp_c: (if .temp then (.temp | gsub("°C"; "") | tonumber) else 0 end),
        gpu_util_pct: (if .gpu_util then (.gpu_util | gsub("%"; "") | tonumber) else 0 end),
        mem_util_pct: (if .mem_util then (.mem_util | gsub("%"; "") | tonumber) else 0 end)
      }'
    '')
  ];

  services.telegraf = {
    enable = true;
    extraConfig = {
      inputs = {
        exec = {
          name_override = "nvtop_intel";
          commands = [ "/run/current-system/sw/bin/nvtop-numeric" ];
          timeout = "5s";
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
