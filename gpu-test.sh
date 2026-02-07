#!/usr/bin/env bash
set -euo pipefail

echo "== Kernel / driver =="
uname -r
lsmod | egrep '^(xe|i915)\b' || true

echo
echo "== DRM devices =="
ls -l /sys/class/drm | sed -n '1,120p'

echo
echo "== Frequency sysfs candidates =="
for f in /sys/class/drm/card*/device/gt_cur_freq_mhz /sys/class/drm/card*/device/gt/gt*/cur_freq_mhz; do
  if [[ -r "$f" ]]; then
    echo "OK  $f = $(cat "$f")"
  fi
done

echo
echo "== HWMON candidates (power/temp) =="
for hw in /sys/class/drm/card*/device/hwmon/hwmon*; do
  [[ -d "$hw" ]] || continue
  echo "-- $hw (name=$(cat "$hw/name" 2>/dev/null || echo '?'))"
  for k in power1_average power1_input temp1_input energy1_input; do
    if [[ -r "$hw/$k" ]]; then
      echo "   $k = $(cat "$hw/$k")"
    fi
  done
done

echo
echo "== Xe PMU presence (perf list xe_*) =="
perf list 2>/dev/null | grep -E '^xe_' | head -n 120 || true

echo
echo "== Try sampling first Xe busy event for 1s =="
PMU="$(perf list 2>/dev/null | awk -F/ '/^xe_/ {print $1; exit}')"
if [[ -z "${PMU:-}" ]]; then
  echo "No xe_ PMU events found. (Either xe PMU not enabled in your kernel, or perf can't see it.)"
  exit 0
fi

# Pick a busy-ish event name from this PMU (names vary by kernel version)
EVENT="$(perf list 2>/dev/null | awk -v p="$PMU" -F/ '$1==p && $2~"busy" {print $2; exit}')"
if [[ -z "${EVENT:-}" ]]; then
  echo "Found PMU '$PMU' but no '*busy*' events under it."
  exit 0
fi

echo "Using PMU=$PMU EVENT=$EVENT"
perf stat -I 1000 -x, -e "$PMU/$EVENT/" -- sleep 1 2>&1 | tail -n 5

