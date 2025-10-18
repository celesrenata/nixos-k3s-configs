#!/run/current-system/sw/bin/bash
/run/wrappers/bin/nvtop -s | /run/current-system/sw/bin/jq '.[0] | {
  device_name: .device_name,
  gpu_clock_mhz: (if .gpu_clock then (.gpu_clock | gsub("MHz"; "") | tonumber) else 0 end),
  temp_c: (if .temp then (.temp | gsub("°C"; "") | tonumber) else 0 end),
  gpu_util_pct: (if .gpu_util then (.gpu_util | gsub("%"; "") | tonumber) else 0 end),
  mem_util_pct: (if .mem_util then (.mem_util | gsub("%"; "") | tonumber) else 0 end)
}'
