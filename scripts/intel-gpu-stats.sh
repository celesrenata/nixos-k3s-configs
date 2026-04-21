#!/run/current-system/sw/bin/bash
set -euo pipefail
export PATH=/run/wrappers/bin:/run/current-system/sw/bin

HOST="$(cat /proc/sys/kernel/hostname)"

# Get one JSON sample (skip first empty reading)
json=$(intel_gpu_top -J -s 1000 2>/dev/null | python3 -c "
import sys, json
# intel_gpu_top outputs a JSON array, read until we get one complete object
buf = ''
depth = 0
for line in sys.stdin:
    buf += line
    depth += line.count('{') - line.count('}')
    if depth == 0 and '{' in buf:
        try:
            obj = json.loads(buf.strip().lstrip('[,'))
            # Skip if all engines are 0 (first sample is often empty)
            print(json.dumps(obj))
            break
        except:
            buf = ''
")

[ -z "$json" ] && exit 0

# Parse with python and emit influx line protocol
python3 -c "
import json, sys
d = json.loads('''$json''')
fields = []
freq = d.get('frequency', {})
if freq.get('actual') is not None: fields.append(f'frequency_actual={freq[\"actual\"]:.0f}')
if freq.get('requested') is not None: fields.append(f'frequency_requested={freq[\"requested\"]:.0f}')
rc6 = d.get('rc6', {})
if rc6.get('value') is not None: fields.append(f'rc6_percent={rc6[\"value\"]:.2f}')
power = d.get('power', {})
if power.get('GPU') is not None: fields.append(f'power_gpu={power[\"GPU\"]:.2f}')
if power.get('Package') is not None: fields.append(f'power_package={power[\"Package\"]:.2f}')
engines = d.get('engines', {})
for name, vals in engines.items():
    tag = name.replace('/', '_').replace(' ', '_')
    if vals.get('busy') is not None: fields.append(f'engines_{tag}_busy={vals[\"busy\"]:.2f}')
irq = d.get('interrupts', {})
if irq.get('count') is not None: fields.append(f'interrupts={irq[\"count\"]:.2f}')
if fields:
    print(f'intel_gpu_top,host=$HOST {\",\".join(fields)}')
"
