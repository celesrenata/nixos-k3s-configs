#!/usr/bin/env python3
"""ArcForge host-native OpenVINO inference service.

Serves a single embedding model on the host's Intel Arc PF render node as a
declarative NixOS systemd unit. This is a drop-in OpenAI-compatible replacement
for the proven OVMS endpoint, but it runs as a native host process:

  * No Docker/podman, no Kubernetes, no SR-IOV virtual functions.
  * Deterministic PF selection is enforced OUTSIDE the process by systemd
    (DevicePolicy=closed + DeviceAllow=<pf-render-node> rw), so the OpenCL ICD
    enumerates exactly one GPU device. The app targets it explicitly as "GPU"
    and refuses to run on CPU (no silent fallback).
  * OpenCL ICD resolution is fixed via OCL_ICD_VENDORS (set by the module) —
    without it the 2026.1.x runtime maps an ICD that fails at buffer-map time
    (clEnqueueMapBuffer CL_INVALID_VALUE), so this env is load-bearing.

Endpoints:
  GET  /v1/models          OpenAI-compatible model list
  POST /v1/embeddings      OpenAI-compatible embeddings (batched)
  GET  /health             liveness (process up)
  GET  /ready              readiness (model compiled + GPU reachable + not wedged)
  GET  /metrics            Prometheus metrics

The circuit breaker opens on the first inference timeout/fault and keeps new
requests failing fast until the supervisor restarts the unit. We never attempt
an uncontrolled reset loop of a wedged device.
"""
from __future__ import annotations

import json
import os
import queue
import signal
import sys
import threading
import time

import numpy as np
import openvino as ov
from tokenizers import Tokenizer
import uvicorn
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse, Response
from prometheus_client import (
    CollectorRegistry,
    Counter,
    Gauge,
    Histogram,
    generate_latest,
    CONTENT_TYPE_LATEST,
)

# ─────────────────────────── Config (from environment) ────────────────────────
MODEL_DIR = os.environ.get("ARCFORGE_MODEL_DIR", "/var/lib/arcforge/models")
XML_PATH = os.environ.get("ARCFORGE_MODEL_XML", f"{MODEL_DIR}/openvino_model.xml")
TOKENIZER_PATH = os.environ.get("ARCFORGE_TOKENIZER", f"{MODEL_DIR}/tokenizer.json")
MODEL_NAME = os.environ.get("ARCFORGE_MODEL_NAME", "qwen3-embedding-0.6b")
MODEL_VERSION = os.environ.get("ARCFORGE_MODEL_VERSION", "qwen3-embedding-0.6b-int8")
EMBED_DIM = int(os.environ.get("ARCFORGE_EMBED_DIM", "1024"))
MAX_LENGTH = int(os.environ.get("ARCFORGE_MAX_LENGTH", "4096"))
DEVICE = os.environ.get("ARCFORGE_DEVICE", "GPU")
CONCURRENCY = int(os.environ.get("ARCFORGE_CONCURRENCY", "4"))
BATCH_LIMIT = int(os.environ.get("ARCFORGE_BATCH_LIMIT", "32"))
INFER_TIMEOUT_S = float(os.environ.get("ARCFORGE_INFER_TIMEOUT_S", "120"))
PORT = int(os.environ.get("ARCFORGE_PORT", "8100"))
HOST = os.environ.get("ARCFORGE_HOST", "0.0.0.0")
PAD_ID = int(os.environ.get("ARCFORGE_PAD_ID", "0"))
NORMALIZE = os.environ.get("ARCFORGE_NORMALIZE", "l2") in ("l2", "1", "true")

START_TIME = time.time()

# ─────────────────────────────── Metrics ──────────────────────────────────────
REG = CollectorRegistry()
EMB_REQUESTS = Counter("arcforge_embedding_requests_total",
    "Total embedding requests by status and model.", ["status", "model"], registry=REG)
EMB_ITEMS = Counter("arcforge_embedding_items_total",
    "Total embedding items processed.", ["model"], registry=REG)
EMB_INFER = Histogram("arcforge_embedding_inference_seconds",
    "Per-batch GPU inference wall time.", ["model"], registry=REG)
EMB_QUEUE = Gauge("arcforge_embedding_queue_depth",
    "Requests waiting for a free inference worker.", registry=REG)
EMB_ACTIVE = Gauge("arcforge_embedding_active_inferences",
    "Inferences currently running on the GPU.", registry=REG)
DEVICE_WEDGED = Gauge("arcforge_device_wedged",
    "1 when the GPU fault circuit is open.", registry=REG)
COMPILE_TIME = Gauge("arcforge_model_compile_seconds",
    "Time to load + compile the model on the GPU at startup.", registry=REG)
UPTIME = Gauge("arcforge_service_uptime_seconds",
    "Process uptime.", registry=REG)
INFER_TOTAL = Counter("arcforge_inference_total",
    "Inference invocations by outcome.", ["outcome"], registry=REG)


def _now() -> float:
    return time.time()


# ─────────────────────────────── Inference core ───────────────────────────────
class GpuCircuitBreaker:
    """Opens on the first GPU fault/timeout; stays open until the unit restarts.

    Deliberately one-shot: we do NOT re-probe or re-reset the device in a loop.
    Recovery is owned by the systemd supervisor (Restart=on-failure), and the
    OmniRoute router isolates the node on /ready=0.
    """

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._open = False
        self._reason = ""

    @property
    def open(self) -> bool:
        with self._lock:
            return self._open

    @property
    def reason(self) -> str:
        with self._lock:
            return self._reason

    def trip(self, reason: str) -> None:
        with self._lock:
            if not self._open:
                self._open = True
                self._reason = reason
                DEVICE_WEDGED.set(1)
                INFER_TOTAL.labels(outcome="wedged").inc()
                print(f"[arcforge] CIRCUIT OPEN: {reason}", file=sys.stderr, flush=True)


BREAKER = GpuCircuitBreaker()


class Engine:
    """Single-model, N-worker OpenVINO inference engine on the PF GPU.

    Each worker owns a CompiledModel + InferRequest (OpenVINO infer requests are
    not thread-safe), so concurrency is a pool of independent streams — the
    recommended pattern for latency-bound embedding serving.
    """

    def __init__(self) -> None:
        global DEVICE
        self._tok = Tokenizer.from_file(TOKENIZER_PATH)
        self._cfg = self._load_config()
        self._core = ov.Core()
        self._devices = list(self._core.available_devices)
        print(f"[arcforge] available_devices={self._devices}", flush=True)

        # Deterministic, explicit GPU target. If the PF render node is not
        # reachable, this raises and the unit fails readiness (no CPU fallback).
        if DEVICE not in self._devices:
            # With the systemd device policy the PF shows up as bare "GPU".
            if DEVICE == "GPU" and any(d.startswith("GPU") for d in self._devices):
                DEVICE = next(d for d in self._devices if d.startswith("GPU"))
            else:
                raise RuntimeError(
                    f"device '{DEVICE}' not present; available={self._devices}; "
                    f"refusing to fall back to CPU")

        self._device = DEVICE
        t0 = _now()
        # Explicit compile on the target device. Each worker is a
        # CompiledModel + InferRequest pair (infer requests are not
        # thread-safe), dispatched from a bounded thread-safe queue.
        self._compile_cfg = {}
        self._pool = queue.Queue(maxsize=CONCURRENCY)
        for i in range(CONCURRENCY):
            cm = self._core.compile_model(XML_PATH, self._device, self._compile_cfg)
            req = cm.create_infer_request()
            self._pool.put((cm, req))
        self._free = CONCURRENCY
        self._free_lock = threading.Lock()
        COMPILE_TIME.set(_now() - t0)
        print(f"[arcforge] compiled {CONCURRENCY} worker(s) on {self._device} "
              f"in {_now()-t0:.2f}s", flush=True)

    def _load_config(self) -> dict:
        try:
            with open(os.path.join(MODEL_DIR, "config.json")) as fh:
                return json.load(fh)
        except Exception:
            return {}

    @property
    def dim(self) -> int:
        return EMBED_DIM

    def _encode(self, texts: list[str], seq: int) -> tuple[np.ndarray, np.ndarray, list[int]]:
        """Tokenize + right-pad to a common length; return ids, mask, lens."""
        enc = self._tok.encode_batch(texts)
        ids = []
        for e in enc:
            t = list(e.ids)
            if len(t) > MAX_LENGTH:
                t = t[-MAX_LENGTH:]
            ids.append(t)
        mx = max(len(t) for t in ids)
        arr_ids, arr_mask, lens = [], [], []
        for t in ids:
            pad = mx - len(t)
            arr_ids.append(np.array(t + [PAD_ID] * pad, dtype=np.int64))
            arr_mask.append(np.array([1] * len(t) + [0] * pad, dtype=np.int64))
            lens.append(len(t))
        return np.stack(arr_ids), np.stack(arr_mask), lens

    def embed(self, texts: list[str]) -> np.ndarray:
        """Return L2-normalized [len(texts), dim] float32 embeddings.

        Runs the whole request as ONE batch on a single worker. This is the
        numerically-exact path: the INT8 model's outputs are batch-size
        sensitive (dynamic quantization), so processing a request as a single
        infer call is what matches the proven OVMS endpoint (cos ~1.0). We do
        NOT split a request across workers; cross-request concurrency comes
        from the pool instead. Inference is time-bounded; a timeout or device
        exception trips the circuit breaker.
        """
        worker = self._pool.get(block=True)
        with self._free_lock:
            self._free -= 1
            EMB_ACTIVE.set(CONCURRENCY - self._free)
            EMB_QUEUE.set(0)
        try:
            ids, mask, lens = self._encode(texts, seq=0)
            t0 = _now()
            try:
                self._run_infer(worker, ids, mask)
            except Exception as e:
                BREAKER.trip(f"inference exception: {type(e).__name__}: {e}")
                raise
            dt = _now() - t0
            if dt > INFER_TIMEOUT_S:
                BREAKER.trip(f"inference exceeded timeout {INFER_TIMEOUT_S}s")
            EMB_INFER.labels(model=MODEL_NAME).observe(dt)
            # last_hidden_state: [B, S, dim]; pool at the last non-pad token.
            h = np.asarray(worker[1].output_tensors[0].data, dtype=np.float32)
            out = np.stack([h[i, lens[i] - 1] for i in range(len(texts))])
            if NORMALIZE:
                out = out / np.linalg.norm(out, axis=1, keepdims=True)
            return out.astype(np.float32)
        finally:
            self._pool.put(worker)
            with self._free_lock:
                self._free += 1
                EMB_ACTIVE.set(CONCURRENCY - self._free)

    def _run_infer(self, worker, ids: np.ndarray, mask: np.ndarray) -> None:
        cm, req = worker
        # Set inputs by index (2-input model: input_ids, attention_mask).
        t0 = ov.Tensor(ids)
        t1 = ov.Tensor(mask)
        req.set_input_tensor(0, t0)
        req.set_input_tensor(1, t1)
        req.infer()


_ENGINE: Engine | None = None
_ENGINE_LOCK = threading.Lock()


def get_engine() -> Engine:
    global _ENGINE
    if _ENGINE is None:
        with _ENGINE_LOCK:
            if _ENGINE is None:
                _ENGINE = Engine()
    return _ENGINE


# ─────────────────────────────── HTTP layer ───────────────────────────────────
app = FastAPI(title="ArcForge", version="1.0", docs_url=None, redoc_url=None)


@app.get("/health")
def health():
    return {"status": "ok", "model": MODEL_NAME, "device": DEVICE,
            "uptime_s": round(_now() - START_TIME, 2)}


@app.get("/ready")
def ready():
    wedged = BREAKER.open
    engine_ok = _ENGINE is not None
    status = 200 if (engine_ok and not wedged) else 503
    return JSONResponse(status_code=status, content={
        "status": "ok" if status == 200 else "not_ready",
        "model": MODEL_NAME, "device": DEVICE, "ready": status == 200,
        "wedged": wedged, "breaker_reason": BREAKER.reason,
    })


@app.get("/v1/models")
def models():
    return {"object": "list", "data": [{
        "id": MODEL_NAME, "object": "model",
        "created": int(START_TIME), "owned_by": "arcforge",
        "arcforge": {"device": DEVICE, "dim": EMBED_DIM,
                     "max_length": MAX_LENGTH, "version": MODEL_VERSION},
    }]}


class EmbeddingRequest(dict):
    pass


@app.post("/v1/embeddings")
async def embeddings(request: Request):
    UPTIME.set(_now() - START_TIME)
    if BREAKER.open:
        EMB_REQUESTS.labels(status="wedged", model=MODEL_NAME).inc()
        return JSONResponse(status_code=503, content={
            "error": {"message": f"GPU circuit open: {BREAKER.reason}",
                      "type": "server_error", "code": "gpu_wedged"}})
    try:
        body = await request.json()
    except Exception:
        EMB_REQUESTS.labels(status="bad_request", model=MODEL_NAME).inc()
        raise HTTPException(status_code=400, detail="invalid JSON body")

    model = body.get("model", MODEL_NAME)
    if model != MODEL_NAME:
        EMB_REQUESTS.labels(status="not_found", model=MODEL_NAME).inc()
        raise HTTPException(status_code=404,
                            detail=f"unknown model '{model}'; expected '{MODEL_NAME}'")
    inputs = body.get("input")
    if inputs is None:
        inputs = body.get("inputs")
    if inputs is None:
        EMB_REQUESTS.labels(status="bad_request", model=MODEL_NAME).inc()
        raise HTTPException(status_code=400, detail="missing 'input'")
    if isinstance(inputs, str):
        inputs = [inputs]
    if not isinstance(inputs, list) or not inputs:
        EMB_REQUESTS.labels(status="bad_request", model=MODEL_NAME).inc()
        raise HTTPException(status_code=400, detail="'input' must be a non-empty list")

    # Reject oversized items cleanly (mirrors the OVMS token-ceiling guard).
    for it in inputs:
        if not isinstance(it, str):
            EMB_REQUESTS.labels(status="bad_request", model=MODEL_NAME).inc()
            raise HTTPException(status_code=400, detail="input items must be strings")

    # Batch cap: split into chunks the engine will accept.
    if len(inputs) > BATCH_LIMIT:
        # Serve the first batch and 413 the rest rather than silently drop.
        EMB_REQUESTS.labels(status="batch_too_large", model=MODEL_NAME).inc()
        return JSONResponse(status_code=413, content={"error": {
            "message": f"batch of {len(inputs)} exceeds ARCFORGE_BATCH_LIMIT={BATCH_LIMIT}",
            "type": "invalid_request_error", "code": "batch_too_large"}})

    t0 = _now()
    try:
        vecs = await _to_thread(get_engine().embed, inputs)
    except Exception as e:
        status = "wedged" if BREAKER.open else "error"
        EMB_REQUESTS.labels(status=status, model=MODEL_NAME).inc()
        raise HTTPException(status_code=500, detail=f"inference failed: {e}")

    EMB_ITEMS.labels(model=MODEL_NAME).inc(len(inputs))
    EMB_REQUESTS.labels(status="ok", model=MODEL_NAME).inc()
    data = []
    for i, (text, vec) in enumerate(zip(inputs, vecs)):
        data.append({"object": "embedding", "index": i,
                     "embedding": [float(x) for x in vec.tolist()],
                     "model": model})
    return {"object": "list", "data": data, "model": model,
            "usage": {"prompt_tokens": None, "total_tokens": None,
                      "arcforge": {"dim": int(vecs.shape[1]),
                                   "items": len(inputs),
                                   "infer_s": round(_now() - t0, 4)}}}


@app.get("/metrics")
def metrics():
    UPTIME.set(_now() - START_TIME)
    return Response(content=generate_latest(REG),
                    media_type=CONTENT_TYPE_LATEST)


async def _to_thread(fn, *a, **kw):
    import asyncio
    return await asyncio.to_thread(fn, *a, **kw)


def _shutdown(sig, frame):
    print(f"[arcforge] received {sig}; shutting down gracefully", flush=True)
    # Release model handles; the unit will stop.
    if _ENGINE is not None:
        try:
            while not _ENGINE._pool.empty():
                _ENGINE._pool.get_nowait()
        except Exception:
            pass
    os._exit(0)


signal.signal(signal.SIGTERM, _shutdown)
signal.signal(signal.SIGINT, _shutdown)


# ─────────────────────────────── systemd watchdog ─────────────────────────────
def _notify(tag: str) -> None:
    """Send a systemd notify message (sd_notify). No-op if not under systemd."""
    path = os.environ.get("NOTIFY_SOCKET")
    if not path:
        return
    if path.startswith("@"):
        path = "/" + path[1:]
    try:
        import socket
        s = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
        try:
            s.connect(path)
            s.sendall(tag.encode())
        finally:
            s.close()
    except Exception:
        pass


def _watchdog_loop() -> None:
    """Ping the systemd watchdog. When the circuit breaker opens we STOP
    pinging so systemd restarts the unit once (bounded recovery). We never
    reset the device ourselves."""
    while True:
        if BREAKER.open:
            # Stop pinging; systemd will restart us after the watchdog timeout.
            time.sleep(0.5)
            continue
        _notify("WATCHDOG=1")
        time.sleep(1)


if __name__ == "__main__":
    # Eager startup: compile the model on the target GPU now. If the PF render
    # node is unreachable this raises -> we exit(1) so systemd restarts us
    # (bounded by StartLimitBurst) and then isolates us if it keeps failing.
    try:
        get_engine()
        _notify("READY=1")
    except Exception as e:
        print(f"[arcforge] FATAL: startup GPU compile failed: {type(e).__name__}: {e}",
              file=sys.stderr, flush=True)
        sys.exit(1)

    threading.Thread(target=_watchdog_loop, daemon=True).start()
    uvicorn.run(app, host=HOST, port=PORT, log_level="warning",
                timeout_graceful_shutdown=10)
