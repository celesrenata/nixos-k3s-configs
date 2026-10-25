#!/usr/bin/env python3
"""ArcForge host-native OpenVINO Qwen3-Reranker service.

Serves the Qwen3-Reranker causal-LM as a host-native, OpenAI/Jina-compatible
rerank endpoint on the PF render node. It is a drop-in provider node for
OmniRoute's /v1/rerank (the memory engine's rerank step): OmniRoute derives
`<base_url>/v1/rerank` from the provider_nodes row and posts
{model, query, documents, top_n, return_documents}; we answer with
{results: [{index, relevance_score, document?}]}.

Same execution discipline as arcforge-embeddings:
  * systemd device policy (closed + PF-only DeviceAllow) selects the device
    outside the process; we target "GPU" explicitly, no CPU fallback.
  * OCL_ICD_VENDORS pins the Intel OpenCL ICD (load-bearing).
from pydantic import BaseModel
  * eager GPU compile at start => readiness reflects the device, not lazy.
from typing import List, Optional, Union, Dict
  * one-shot circuit breaker -> stop pinging -> systemd restarts once.

Scoring (official int8-ov README, causal-LM yes/no logit):
  prompt = chat system ("Judge whether the Document meets the requirements
           ... can only be \"yes\" or \"no\"") + user
           "<Instruct>: {instr}\n<Query>: {q}\n<Document>: {doc}" + assistant
           start.
  left-padded batch; score = P("yes") = softmax([logit_yes, logit_no])[0]
  over the last (rightmost) position's logits; yes/no token ids are read from
  the bundled tokenizer at startup (single tokens in this vocab).
"""
from __future__ import annotations

import json
import math
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
MODEL_DIR   = os.environ.get("ARCFORGE_RERANK_MODEL_DIR", "/var/lib/arcforge/reranker")
XML_PATH    = os.environ.get("ARCFORGE_RERANK_XML", f"{MODEL_DIR}/openvino_model.xml")
TOKENIZER_PATH = os.environ.get("ARCFORGE_RERANK_TOKENIZER", f"{MODEL_DIR}/tokenizer.json")
MODEL_NAME  = os.environ.get("ARCFORGE_RERANK_MODEL_NAME", "qwen3-reranker-0.6b")
MODEL_VERSION = os.environ.get("ARCFORGE_RERANK_MODEL_VERSION", "qwen3-reranker-0.6b-int8")
from typing import List, Optional, Union, Dict
from pydantic import BaseModel

# ─────────────────────────── Config (from environment) ────────────────────────
MODEL_DIR = os.environ.get("ARCFORGE_RERANK_MODEL_DIR", "/var/lib/arcforge/reranker")
XML_PATH = os.environ.get("ARCFORGE_RERANK_XML", f"{MODEL_DIR}/openvino_model.xml")
TOKENIZER_PATH = os.environ.get("ARCFORGE_RERANK_TOKENIZER", f"{MODEL_DIR}/tokenizer.json")
MODEL_NAME = os.environ.get("ARCFORGE_RERANK_MODEL_NAME", "qwen3-reranker-0.6b")
MODEL_VERSION = os.environ.get("ARCFORGE_RERANK_MODEL_VERSION", "qwen3-reranker-0.6b-int8")
MAX_LENGTH = int(os.environ.get("ARCFORGE_RERANK_MAX_LENGTH", "4096"))
DEVICE = os.environ.get("ARCFORGE_DEVICE", "GPU")
CONCURRENCY = int(os.environ.get("ARCFORGE_RERANK_CONCURRENCY", "4"))
BATCH_LIMIT = int(os.environ.get("ARCFORGE_RERANK_BATCH_LIMIT", "64"))
INFER_TIMEOUT_S = float(os.environ.get("ARCFORGE_RERANK_INFER_TIMEOUT_S", "120"))
PORT = int(os.environ.get("ARCFORGE_RERANK_PORT", "8101"))
HOST = os.environ.get("ARCFORGE_RERANK_HOST", "0.0.0.0")
PAD_ID = int(os.environ.get("ARCFORGE_RERANK_PAD_ID", "151643"))
VOCAB_SIZE = 151669

START_TIME = time.time()

# ─────────────────────────────── Metrics ──────────────────────────────────────
REG = CollectorRegistry()
RR_REQUESTS = Counter("arcforge_rerank_requests_total",
    "Total rerank requests by status and model.", ["status", "model"], registry=REG)
RR_PAIRS = Counter("arcforge_rerank_pairs_total",
    "Total (query, doc) pairs scored.", ["model"], registry=REG)
RR_INFER = Histogram("arcforge_rerank_inference_seconds",
    "Per-batch GPU inference wall time.", ["model"], registry=REG)
RR_DEVICE_WEDGED = Gauge("arcforge_rerank_device_wedged",
    "1 if the GPU circuit breaker is open.", registry=REG)
RR_COMPILE_TIME = Gauge("arcforge_rerank_compile_seconds",
    "Eager GPU compile time at startup.", registry=REG)
INFER_TOTAL = Counter("arcforge_rerank_inference_total",
    "Inference invocations by outcome.", ["outcome"], registry=REG)

def _now() -> float:
    return time.time()

# ─────────────────────────────── Inference core ───────────────────────────────
class GpuCircuitBreaker:
    """Opens on the first GPU fault/timeout; stays open until the unit restarts."""

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
                RR_DEVICE_WEDGED.set(1)
                INFER_TOTAL.labels(outcome="wedged").inc()
                print(f"[arcforge-rerank] CIRCUIT OPEN: {reason}", file=sys.stderr, flush=True)

BREAKER = GpuCircuitBreaker()
ENGINE = None
ENGINE_LOCK = threading.Lock()

def get_engine() -> "Engine":
    global ENGINE
    if ENGINE is None:
        with ENGINE_LOCK:
            if ENGINE is None:
                ENGINE = Engine()
    return ENGINE

class Engine:
    """Single causal-LM model, N-worker OpenVINO engine on the PF GPU."""

    def __init__(self) -> None:
        global DEVICE
        self._tok = Tokenizer.from_file(TOKENIZER_PATH)
        self._core = ov.Core()
        self._devices = list(self._core.available_devices)
        print(f"[arcforge-rerank] available_devices={self._devices}", flush=True)

        if DEVICE not in self._devices:
            if DEVICE == "GPU" and any(d.startswith("GPU") for d in self._devices):
                DEVICE = next(d for d in self._devices if d.startswith("GPU"))
            else:
                raise RuntimeError(
                    f"device '{DEVICE}' not present; refusing CPU fallback")

        self._device = DEVICE
        yes_enc = self._tok.encode("yes", add_special_tokens=False)
        no_enc = self._tok.encode("no", add_special_tokens=False)
        if len(yes_enc.ids) != 1 or len(no_enc.ids) != 1:
            raise RuntimeError(f"expected single-token yes/no, got {yes_enc.ids}/{no_enc.ids}")
        self._yes_id = int(yes_enc.ids[0])
        self._no_id = int(no_enc.ids[0])
        print(f"[arcforge-rerank] yes_id={self._yes_id} no_id={self._no_id} pad_id={PAD_ID}", flush=True)
        self._pre_ids = list(self._tok.encode(
            "<|" + "im_start" + "|>system\nJudge whether the Document meets the requirements based on "
            "the Query and the Instruct provided. Note that the answer can only be \"yes\" or \"no\".\n\n"
            "<|" + "im_start" + "|>user\n", add_special_tokens=False).ids)
        suf = ("<|" + "im_end" + "|\n<" + "|im_start" + "|>assistant\n<" + "|think" + ">\n\n<" + "/" + "think" + ">\n\n")
        self._suf_ids = list(self._tok.encode(suf, add_special_tokens=False).ids)
        print(f"[arcforge-rerank] prefix_tokens={len(self._pre_ids)} suffix_tokens={len(self._suf_ids)}", flush=True)
        self._compile_cfg = {}
        self._pool = queue.Queue(maxsize=CONCURRENCY)
        t0 = _now()
        for _ in range(CONCURRENCY):
            cm = self._core.compile_model(XML_PATH, self._device, self._compile_cfg)
            self._pool.put(cm.create_infer_request())
        self._free = CONCURRENCY
        self._free_lock = threading.Lock()
        RR_COMPILE_TIME.set(_now() - t0)
        print(f"[arcforge-rerank] compiled {CONCURRENCY} worker(s) on {self._device} in {_now()-t0:.2f}s", flush=True)

    def _run_infer(self, req, ids: np.ndarray, mask: np.ndarray, pos: np.ndarray) -> None:
        # OpenVINO requires ov.Tensor wrappers (not raw numpy arrays).
        t_ids = ov.Tensor(ids)
        t_mask = ov.Tensor(mask)
        t_pos = ov.Tensor(pos)
        req.set_input_tensor(0, t_ids)
        req.set_input_tensor(1, t_mask)
        req.set_input_tensor(2, t_pos)
        req.infer()

    def _encode_pairs(self, queries: List[str], docs: List[str]) -> List[tuple]:
        """Tokenize each pair into (pre+body+suf) id lists, truncated to MAX_LENGTH."""
        max_budget = MAX_LENGTH - len(self._pre_ids) - len(self._suf_ids)
        pairs = []
        for q, d in zip(queries, docs):
            body = "<Instruct>: {}\n<Query>: {}\n<Document>: {}".format(
                "Given a web search query, retrieve relevant passages that answer the query", q, d)
            enc = self._tok.encode(body, add_special_tokens=False)
            body_ids = list(enc.ids)
            if len(body_ids) > max_budget:
                # "longest_first": keep the rightmost tokens (matches the
                # embedding service truncation).
                body_ids = body_ids[-max_budget:]
            pairs.append(self._pre_ids + body_ids + self._suf_ids)
        return pairs

    def _pad_chunk(self, ids_list: List[List[int]]) -> tuple:
        """Left-pad a list of id lists to the chunk's max length.

        Position ids are arange over the padded length: the last (rightmost,
        real) token of every row sits at the same absolute position, which is
        exactly what the causal-LM logits at position -1 need.
        """
        T = max(len(s) for s in ids_list)
        arr_ids, arr_mask, arr_pos = [], [], []
        for s in ids_list:
            pad = T - len(s)
            arr_ids.append(np.array([PAD_ID] * pad + s, dtype=np.int64))
            arr_mask.append(np.array([0] * pad + [1] * len(s), dtype=np.int64))
            arr_pos.append(np.array(list(range(T)), dtype=np.int64))
        return (np.stack(arr_ids), np.stack(arr_mask), np.stack(arr_pos))

    def _max_batch_for(self, seq_len: int) -> int:
        """Largest batch B with the [B, seq_len, V] f32 logits tensor under the
        device's ~4 GiB single-allocation limit."""
        budget = int(3.5 * 1024 ** 3)  # 3.5 GiB headroom under the 4 GiB cap
        return max(1, budget // (seq_len * VOCAB_SIZE * 4))

    def _score_chunk(self, chunk: List[List[int]]) -> List[float]:
        worker = self._pool.get(block=True)
        try:
            ids, mask, pos = self._pad_chunk(chunk)
            try:
                self._run_infer(worker, ids, mask, pos)
            except Exception as e:
                BREAKER.trip(f"inference exception: {type(e).__name__}: {e}")
                raise
            logits = np.asarray(worker.output_tensors[0].data, dtype=np.float32)
            last = logits[:, -1, :]  # [B, V] — P(yes) at the last real token
            yes = last[:, self._yes_id]
            no = last[:, self._no_id]
            m = np.maximum(yes, no)
            return (np.exp(yes - m) / (np.exp(yes - m) + np.exp(no - m))).tolist()
        finally:
            self._pool.put(worker)

    def score(self, queries: List[str], docs: List[str]) -> List[float]:
        if len(queries) != len(docs):
            raise ValueError(f"queries({len(queries)}) != docs({len(docs)})")
        if len(queries) == 0:
            return []
        if len(queries) > BATCH_LIMIT:
            raise ValueError(f"batch size {len(queries)} > limit {BATCH_LIMIT}")

        pairs = self._encode_pairs(queries, docs)
        # Greedy chunks: each fits the device's logits allocation limit.
        probs: List[float] = []
        t0 = _now()
        start = 0
        n = len(pairs)
        while start < n:
            max_b = self._max_batch_for(max(len(p) for p in pairs[start:]))
            chunk = pairs[start:start + max_b]
            probs.extend(self._score_chunk(chunk))
            start += len(chunk)
        dt = _now() - t0
        if dt > INFER_TIMEOUT_S:
            BREAKER.trip(f"inference exceeded timeout {INFER_TIMEOUT_S}s")
        RR_INFER.labels(model=MODEL_NAME).observe(dt)
        return probs

# ─────────────────────────────── FastAPI app ──────────────────────────────────
app = FastAPI(title="ArcForge Rerank", version="1.0", docs_url=None, redoc_url=None)

@app.get("/health")
def health():
    return {"status": "ok", "model": MODEL_NAME, "device": DEVICE, "uptime_s": round(_now() - START_TIME, 2)}

@app.get("/ready")
def ready():
    wedged = BREAKER.open
    engine_ok = ENGINE is not None
    status = 200 if (engine_ok and not wedged) else 503
    return JSONResponse(
        status_code=status,
        content={
            "status": "ok" if status == 200 else "not_ready",
            "model": MODEL_NAME,
            "device": DEVICE,
            "ready": status == 200,
            "wedged": wedged,
            "breaker_reason": BREAKER.reason,
        },
    )

@app.get("/v1/models")
def models():
    return {
        "object": "list",
        "data": [{
            "id": MODEL_NAME,
            "object": "model",
            "created": int(START_TIME),
            "owned_by": "arcforge",
            "arcforge": {"device": DEVICE, "max_length": MAX_LENGTH, "version": MODEL_VERSION},
        }],
    }

def documentText(doc: Union[str, Dict[str, str]]) -> str:
    return doc if isinstance(doc, str) else (doc.get("text") or "")

class RerankRequest(BaseModel):
    model: str
    query: str
    documents: List[Union[str, Dict[str, str]]]
    top_n: Optional[int] = None
    return_documents: Optional[bool] = None

class RerankResult(BaseModel):
    index: int
    relevance_score: float
    document: Optional[str] = None

class RerankResponse(BaseModel):
    results: List[RerankResult]

@app.post("/v1/rerank")
async def rerank(req: RerankRequest):
    RR_REQUESTS.labels(status="success", model=MODEL_NAME).inc()
    RR_PAIRS.labels(model=MODEL_NAME).inc(len(req.documents))
    if BREAKER.open:
        return JSONResponse(status_code=503, content={
            "error": {"message": f"GPU circuit open: {BREAKER.reason}", "type": "server_error", "code": "gpu_wedged"},
        })
    try:
        engine = get_engine()
        scores = engine.score([req.query] * len(req.documents), [documentText(d) for d in req.documents])
        top_n = req.top_n if req.top_n is not None else len(scores)
        results = sorted([RerankResult(index=i, relevance_score=float(scores[i])) for i in range(len(scores))],
                         key=lambda r: -r.relevance_score)[:top_n]
        if req.return_documents is True:
            docs = [documentText(d) for d in req.documents]
            results = [RerankResult(index=r.index, relevance_score=r.relevance_score, document=docs[r.index])
                       for r in results]
        return RerankResponse(results=results)
    except Exception as e:
        RR_REQUESTS.labels(status="error", model=MODEL_NAME).inc()
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/metrics")
def metrics():
    return Response(generate_latest(REG), media_type=CONTENT_TYPE_LATEST)

# ─────────────────────────────── Watchdog + main ──────────────────────────────
def watchdog() -> None:
    while True:
        time.sleep(60)
        if BREAKER.open:
            print(f"[arcforge-rerank] CIRCUIT STILL OPEN: {BREAKER.reason}", file=sys.stderr, flush=True)
        else:
            print(f"[arcforge-rerank] uptime {_now() - START_TIME:.1f}s, device {DEVICE} OK", flush=True)

def main() -> None:
    print(f"[arcforge-rerank] starting {MODEL_NAME} on {DEVICE} port {PORT}", flush=True)
    try:
        engine = get_engine()
        print(f"[arcforge-rerank] initialized engine (max_length={MAX_LENGTH}, concurrency={CONCURRENCY})", flush=True)
    except Exception as e:
        print(f"[arcforge-rerank] engine init failed: {type(e).__name__}: {e}", file=sys.stderr, flush=True)
        sys.exit(1)
    t = threading.Thread(target=watchdog, daemon=True)
    t.start()
    uvicorn.run(app, host=HOST, port=PORT, log_level="warning")

if __name__ == "__main__":
    main()
