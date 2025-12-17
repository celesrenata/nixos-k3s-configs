#!/run/current-system/sw/bin/bash
set -euo pipefail
export PATH=/run/wrappers/bin:/run/current-system/sw/bin

HOST="$(cat /proc/sys/kernel/hostname)"
PMU="xe_0000_00_02.0"

PERF="/run/wrappers/bin/perf"
[[ -x "$PERF" ]] || PERF="$(command -v perf || true)"
[[ -x "$PERF" ]] || exit 0

out="$("$PERF" stat -x, \
  -e "$PMU/engine-active-ticks/,$PMU/engine-total-ticks/,$PMU/gt-actual-frequency/,$PMU/gt-requested-frequency/,$PMU/gt-c6-residency/" \
  -- sleep 1 2>&1)"

# Parse: value,unit,event,...
val() {
  local ev="$1"
  echo "$out" | awk -F, -v ev="$ev" '
    {
      v=$1; e=$3
      gsub(/ /,"",v); gsub(/ /,"",e)
      sub(/\/$/,"",e)        # 1) drop trailing slash
      sub(/^.*\//,"",e)      # 2) drop PMU prefix up to last slash
      if (e==ev) { print v; exit }
    }'
}

unit() {
  local ev="$1"
  echo "$out" | awk -F, -v ev="$ev" '
    {
      u=$2; e=$3
      gsub(/ /,"",u); gsub(/ /,"",e)
      sub(/\/$/,"",e)
      sub(/^.*\//,"",e)
      if (e==ev) { print u; exit }
    }'
}

active="$(val engine-active-ticks)"
total="$(val engine-total-ticks)"
freq_actual="$(val gt-actual-frequency)"
freq_req="$(val gt-requested-frequency)"
c6_val="$(val gt-c6-residency)"
c6_unit="$(unit gt-c6-residency)"

busy=""
if [[ -n "$active" && -n "$total" && "$total" != "0" ]]; then
  busy="$(awk -v a="$active" -v t="$total" 'BEGIN { printf "%.2f", (a/t)*100.0 }')"
fi

fields=()
# Grafana 23091 expects these names
[[ -n "$freq_actual" ]] && fields+=("frequency_actual=$freq_actual")              # MHz
[[ -n "$busy"        ]] && fields+=("engines_Render/3D_busy=$busy")              # %
# Optional extras (won’t break the dashboard)
[[ -n "$freq_req"    ]] && fields+=("frequency_requested=$freq_req")             # MHz
[[ -n "$c6_val"      ]] && fields+=("gt_c6_residency=$c6_val")                   # 0.. (ms on your system)

[[ "${#fields[@]}" -eq 0 ]] && exit 0
printf 'intel_gpu_top,host=%s %s\n' "$HOST" "$(IFS=,; echo "${fields[*]}")"

