#!/bin/bash

# Get nvtop output and transform it to match intel_gpu_top format
nvtop_output=$(nvtop --snapshot 2>/dev/null)

if [ $? -eq 0 ] && [ -n "$nvtop_output" ]; then
    # Extract values from nvtop JSON output
    device_name=$(echo "$nvtop_output" | grep -o '"device_name": "[^"]*"' | cut -d'"' -f4)
    gpu_clock=$(echo "$nvtop_output" | grep -o '"gpu_clock": "[^"]*"' | cut -d'"' -f4 | sed 's/MHz//')
    mem_util=$(echo "$nvtop_output" | grep -o '"mem_util": "[^"]*"' | cut -d'"' -f4 | sed 's/%//')
    gpu_util=$(echo "$nvtop_output" | grep -o '"gpu_util": "[^"]*"' | cut -d'"' -f4 | sed 's/%//' | sed 's/null/0/')
    
    # Set defaults for null values
    [ "$gpu_clock" = "null" ] && gpu_clock="0"
    [ "$mem_util" = "null" ] && mem_util="0"
    [ "$gpu_util" = "" ] && gpu_util="0"
    
    # Output in intel_gpu_top compatible format
    cat << EOF
{
  "frequency": ${gpu_clock:-0},
  "engine_render_busy": ${gpu_util:-0},
  "engine_copy_busy": 0,
  "engine_video_busy": 0,
  "engine_videoenhance_busy": 0,
  "memory_utilization": ${mem_util:-0}
}
EOF
else
    # Fallback if nvtop fails
    cat << EOF
{
  "frequency": 0,
  "engine_render_busy": 0,
  "engine_copy_busy": 0,
  "engine_video_busy": 0,
  "engine_videoenhance_busy": 0,
  "memory_utilization": 0
}
EOF
fi
