{ pkgs, ... }:
let
  intel-gpu-stats = pkgs.writeShellScript "intel-gpu-stats" ''
    export PATH=${pkgs.intel-gpu-tools}/bin:${pkgs.python3}/bin:$PATH
    HOST="$(cat /proc/sys/kernel/hostname)"

    json=$(intel_gpu_top -J -s 1000 2>/dev/null | python3 -c "
    import sys, json
    buf = ''
    depth = 0
    for line in sys.stdin:
        buf += line
        depth += line.count('{') - line.count('}')
        if depth == 0 and '{' in buf:
            try:
                obj = json.loads(buf.strip().lstrip('[,'))
                print(json.dumps(obj))
                break
            except:
                buf = ''
    ")

    [ -z "$json" ] && exit 0

    python3 -c "
    import json
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
  '';
in
{
  environment.systemPackages = [ pkgs.intel-gpu-tools ];

  systemd.services.telegraf.serviceConfig.EnvironmentFile =
    "/etc/nixos/.config/PasswordFiles/influx.env";

  services.telegraf = {
    enable = true;
    extraConfig = {
      inputs.exec = {
        commands = [ "${intel-gpu-stats}" ];
        interval = "10s";
        timeout = "10s";
        data_format = "influx";
      };

      outputs.influxdb_v2 = {
        urls = [ "http://10.1.1.12:8086" ];
        organization = "celestium.life";
        bucket = "influx";
        token = "$INFLUX_TOKEN";
      };
    };
  };
}
