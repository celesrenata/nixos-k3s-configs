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
    inferTimeoutSec = 120;        # circuit-breaker timeout
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
