# ArcForge — host-native Intel Arc (iGPU PF) inference

`ArcForge` serves model inference **natively on the NixOS host** on the
Intel Arc **physical function (PF)**, as a plain systemd service. It replaces
the containerized / Kubernetes paths (the old podman OVMS endpoint, the
`k3s`-passthrough GPU pods) that required GPU-passthrough plumbing that broke
whenever the PF was reloaded or reset.

## Why this works where the old paths failed

| Concern | Old path | ArcForge |
|---|---|---|
| GPU passthrough | Podman `--device` / k3s device plugin | `DevicePolicy=closed` + `DeviceAllow=<PF> rw` |
| Device selection | Implicit (loader saw every render node, incl. VFs) | **Deterministic**: only the PF node is openable; `verify-pf.sh` maps it to the expected PCI address at activation |
| Runtime | OVMS container (its own OpenVINO) | Host `openvino` Python env (2026.4.0, the same major version that produced the on-disk IR — no runtime mismatch) |
| Concurrency | single worker | N parallel GPU worker streams (one `InferRequest` each) |
| GPU-fault recovery | silent hang / CPU fallback | circuit breaker → stops pinging → systemd `WatchdogSec` restarts **once**; no userspace reset loop |
| Fallback | silent CPU (wrong device) | **none** — fails loudly on the GPU |

## What runs on gremlin-1 (vertical slice)

* `arcforge-embeddings` — the inference service (`Type=notify`, watchdog 30s).
* `arcforge-model-fetch` — one-time validation that the IR + tokenizer are
  present (the slice points at the proven OVMS-extracted IR, read-only).
* `arcforge-verify` — one-shot guard that the PF render node still maps to
  PCI `0000:00:02.0` (fail loudly on topology change).

It serves on **port 8100** (a dedicated canary port), so the proven podman
OVMS on **8000** stays up for A/B comparison until cutover.

## Option surface

```nix
services.arcforge = {
  enable = true;
  port = 8100;                    # API + metrics port
  bindAddress = "0.0.0.0";
  device = {
    renderNode = "/dev/dri/renderD128";  # PF render node
    pciAddress = "0000:00:02.0";        # verified at activation
  };
  model = {
    dir = "/var/lib/ovms-embeddings/models/OpenVINO/Qwen3-Embedding-0.6B-int8-ov";
    xml = "…/openvino_model.xml";
    tokenizer = "…/tokenizer.json";
    name = "qwen3-embedding-0.6b";
    version = "qwen3-embedding-0.6b-int8";
    dim = 1024;
    maxLength = 4096;             # per-item token ceiling (FEAT-003)
    normalize = "l2";
    padId = 0;
  };
  inference = {
    concurrency = 4;              # parallel GPU worker streams
    batchLimit = 32;              # max items per /v1/embeddings request
    inferTimeoutSec = 60;         # hard wall-clock bound on ONE GPU call
    probeIntervalSec = 30;        # idle-device liveness probe (0 = off)
    probeTimeoutSec = 10;         # bound for one probe (~15 ms in practice)
  };
  watchdogSec = 30;               # systemd watchdog (bounded restart)
  restartLimitBurst = 5;          # restarts in 60s before failed state
  metrics = { enable = false; };   # wire Prometheus/Grafana on rollout
};
```

## Endpoints (OpenAI-compatible)

* `GET /ready` — `{"status":"ok","device":"GPU","ready":true,"wedged":false}`
* `GET /v1/models`
* `POST /v1/embeddings` — `{"input": [...], "model": "qwen3-embedding-0.6b"}`
* `GET /metrics` — Prometheus (requests, inference-latency histogram,
  device-wedged gauge, model compile time, active inferences, queue depth)

## Hang detection (wedged i915)

A wedged device does not raise: it blocks **inside** `req.infer()`, and OpenVINO
has no inference timeout. So the old guard — comparing elapsed time *after* the
call returned — could never fire, the worker pool silently shrank to zero, and
`/ready` kept answering `200` while every request hung. Two detectors now feed
the same circuit breaker:

| Detector | Fires when | Effect |
|---|---|---|
| Request path (`_run_bounded`) | one GPU call exceeds `inferTimeoutSec` | breaker opens, request fails fast, `/ready` 503 |
| Idle probe (`_probe_loop`) | a 1-token call exceeds `probeTimeoutSec` while a worker is idle | breaker opens **before** traffic arrives, node drained |

On a trip the service stops pinging the systemd watchdog (embeddings and rerank
are both `Type=notify` with `WatchdogSec`), so the unit is restarted once after
`watchdogSec` (`StartLimitBurst` bounds a restart loop). A worker whose infer may
still be blocked in the driver is never recycled into the pool.

Signals: `arcforge_device_wedged` / `arcforge_rerank_device_wedged` (1 = wedged),
`arcforge_watchdog_probe_total{outcome="ok|skipped"}` (a probe that times out
trips the breaker and shows up in `breaker_reason`),
`arcforge_fault_injection_stall_seconds` (non-zero only during a drill).

### Watchdog drill (proves the detector without touching production)

`ARCFORGE_FAULT_INFER_STALL_S` blocks the worker exactly where a wedged driver
does. Do **not** drill the production unit: `/etc` is read-only under NixOS, so a
systemd drop-in is impossible, and `systemctl set-environment` only reaches
variables the unit does not already define (`ARCFORGE_INFER_TIMEOUT_S` is set by
the module, so it could not be shortened that way).

Run the patched script as a **transient unit on a spare port, on CPU**, with its
own short timeouts — the production unit and the GPU are untouched:

```bash
# on one host: copy the production env, then override the drill knobs
PY=$(systemctl show arcforge-embeddings -p ExecStart --value \
       | grep -oE '/nix/store/[^ ]+/bin/python[0-9.]*' | head -1)
PID=$(systemctl show arcforge-embeddings -p MainPID --value)
tr '\0' '\n' < /proc/$PID/environ | grep '^ARCFORGE_' \
  | grep -vE '^ARCFORGE_(PORT|DEVICE|CONCURRENCY|INFER_TIMEOUT_S|PROBE_INTERVAL_S|PROBE_TIMEOUT_S|FAULT_INFER_STALL_S)=' \
  > /root/drill.env
cat >> /root/drill.env <<EOF
ARCFORGE_PORT=8199
ARCFORGE_DEVICE=CPU
ARCFORGE_CONCURRENCY=1
ARCFORGE_INFER_TIMEOUT_S=1
ARCFORGE_PROBE_INTERVAL_S=5
ARCFORGE_PROBE_TIMEOUT_S=3
ARCFORGE_FAULT_INFER_STALL_S=5
EOF
cat > /root/drill-run.sh <<EOF
#!/bin/sh
set -a; . /root/drill.env; set +a
exec $PY /etc/nixos/modules/services/arcforge/service.py
EOF
chmod +x /root/drill-run.sh
systemd-run --unit=arcforge-drill --property=Type=notify \
  --property=WatchdogSec=5 --property=Restart=on-failure \
  --property=RestartSec=1 /root/drill-run.sh
```

Expect, within ~1 s of the first request (or of the next idle probe):

* `POST :8199/v1/embeddings` → `500` `"inference did not return within 1.0s"`
  (in the measured drill: failed after 1.37 s).
* `GET :8199/ready` → `503` with `"wedged":true` and the breaker reason; the
  metric `arcforge_device_wedged` becomes `1`.
* `journalctl -u arcforge-drill` → `CIRCUIT OPEN: ...`, then after 5 s
  `Watchdog timeout (limit 5s)!` → `SIGABRT` → `Failed with result 'watchdog'`
  → restart → `/ready` `200` again.

```bash
systemctl stop arcforge-drill && systemctl reset-failed arcforge-drill
rm -f /root/drill.env /root/drill-run.sh
```

For the rerank service use `rerank-service.py` with `ARCFORGE_RERANK_PORT=8198`
instead of `ARCFORGE_PORT` (it shares the probe/fault variables; its breaker
metric is `arcforge_rerank_device_wedged`). In the measured drill a request
during a wedge fails fast with `503 {"code":"gpu_wedged"}` (1.5 ms) and the unit
is restarted by the same watchdog path.

## GPU kernel cache (IGC / OpenCL JIT)

The Intel OpenCL compiler (IGC) JIT-compiles a kernel the first time a shape is
seen. On gremlin-1 it has crashed on its own (`CL_BUILD_PROGRAM_FAILURE` followed
by `*** stack smashing detected ***`), taking the unit down until systemd
restarted it. The service therefore keeps a kernel blob cache, so a restart
re-imports what it already compiled instead of re-entering the JIT for every
shape:

```nix
inference.cache = "arcforge";   # systemd CacheDirectory -> /var/cache/arcforge
                                # null disables the cache
```

Each service gets its own directory (`arcforge` for embeddings,
`arcforge-rerank` for the reranker) through `CacheDirectory=`, owned by the
service user, exported as `ARCFORGE_CACHE_DIR`. The first compile of a genuinely
new shape still happens in-process — the cache removes the recompiles after a
restart, it does not remove the compile itself.

**Clear the cache after an IGC / OpenVINO / driver upgrade** so an old blob is
never imported:

```bash
systemctl stop arcforge-embeddings && rm -rf /var/cache/arcforge
systemctl start arcforge-embeddings
```

## Validation performed (gremlin-1)

* PF confirmed: `/dev/dri/renderD128` → PCI `0000:00:02.0` (sysfs).
* Embeddings numerically equivalent to the working endpoint:
  mean cosine ≈ **0.9996**, max abs diff ≈ 0.0056 (both int8, L2-normalized).
* 4-worker GPU pool: concurrent load parallelizes (aggregate throughput
  scales with concurrency; all outputs stay 1024-dim).
* GPU compile ~12 s; readiness reflects the device (eager compile at start).
* k3s workloads and the proven OVMS are untouched.

## Rollout plan (one node at a time, each validated)

1. **gremlin-1** — done (this slice, port 8100). Validate against 8000.
2. **gremlin-2 / 3 / 4** — enable the same module (same port, its own PF
   render node). Validate each node independently.
3. **Cutover** — point OmniRoute / consumers at the native port (or move the
   slice to 8000 and retire the podman OVMS). Enable `metrics.enable` on the
   cluster-init node to land the Prometheus/Grafana manifests.
