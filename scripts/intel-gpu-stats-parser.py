#!/usr/bin/env python3
import sys, json, socket

host = socket.gethostname()
buf = ""
depth = 0
for line in sys.stdin:
    buf += line
    depth += line.count("{") - line.count("}")
    if depth == 0 and "{" in buf:
        try:
            obj = json.loads(buf.strip().lstrip("[,"))
            fields = []
            freq = obj.get("frequency", {})
            if freq.get("actual") is not None: fields.append(f'frequency_actual={freq["actual"]:.0f}')
            if freq.get("requested") is not None: fields.append(f'frequency_requested={freq["requested"]:.0f}')
            rc6 = obj.get("rc6", {})
            if rc6.get("value") is not None: fields.append(f'rc6_percent={rc6["value"]:.2f}')
            power = obj.get("power", {})
            if power.get("GPU") is not None: fields.append(f'power_gpu={power["GPU"]:.2f}')
            if power.get("Package") is not None: fields.append(f'power_package={power["Package"]:.2f}')
            engines = obj.get("engines", {})
            for name, vals in engines.items():
                tag = name.replace("/", "_").replace(" ", "_")
                if vals.get("busy") is not None: fields.append(f'engines_{tag}_busy={vals["busy"]:.2f}')
            irq = obj.get("interrupts", {})
            if irq.get("count") is not None: fields.append(f'interrupts={irq["count"]:.2f}')
            if fields:
                print(f'intel_gpu_top,host={host} {",".join(fields)}')
            break
        except:
            buf = ""
