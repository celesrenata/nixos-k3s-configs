#!/usr/bin/env bash
echo "== Xe freq files (act/cur) =="
find /sys/class/drm/card*/device -maxdepth 6 -type f \
  \( -name act_freq -o -name cur_freq -o -name rpn_freq -o -name rpa_freq \) \
  -print -exec cat {} \; 2>/dev/null

