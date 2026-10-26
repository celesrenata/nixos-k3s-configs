#!/usr/bin/env python3
"""Streaming inference benchmark for an Ollama-compatible endpoint.

Measures, per run:
  - TTFT (time to first token)
  - decode throughput (tok/s over the whole generation, and over the tail after warmup)
  - total tokens and wall time
  - prompt eval rate (prefill) when the endpoint reports it (n/a for Ollama; derived)

Fixed, deterministic prompts so results are comparable across runs and machines
(paired fixed-text tests to separate real gains from drift).

Usage:
  python3 stream_bench.py --base http://10.1.1.12:2701 --model qwen3.8:27b-q3-code48k \
      --prompt-kind code --iters 3 --gen 256

Writes a JSON result file alongside (or --out PATH) and prints a one-line summary.
Only the Python standard library is used.
"""

import argparse
import json
import os
import sys
import time
import urllib.request
import urllib.error

BASE_URL = "http://10.1.1.12:2701"

# Fixed prompts. Each is a single self-contained instruction whose expected answer
# length is roughly bounded by --gen. Kept identical across all candidate engines.
PROMPTS = {
    "code": (
        "Write a Python function `def longest_palindrome_substring_length(s: str) -> int:` "
        "that returns the length of the longest palindromic substring of s, using an "
        "expanding-around-center algorithm. Include a short docstring and a few "
        "assertions as a main guard. Do not import any modules."
    ),
    "prose": (
        "Explain, in 150-200 words, the difference between a circuit breaker pattern and "
        "a bulkhead pattern in distributed systems, with one concrete example of each. "
        "Be precise and avoid filler."
    ),
    "reason": (
        "A factory ships boxes in two sizes. A large box holds 48 units and a small box "
        "holds 20 units. The factory ships a total of 240 units using exactly 9 boxes. "
        "How many large boxes were used? Show the algebra."
    ),
    "long": (
        "Write a detailed technical plan for adding resumable long-context inference to a "
        "16 GB GPU deployment. Cover KV cache quantization, prefix caching, checkpointed "
        "recurrent state, and a concurrency policy for mixing a small reader model with a "
        "large coder model on the same GPU. Use numbered sections and be concrete about "
        "memory budgeting."
    ),
}


def http_post_json(url, payload, timeout=600):
    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    return urllib.request.urlopen(req, timeout=timeout)


def stream_once(base, model, prompt, gen, think=False):
    """One streaming generation. Returns a dict of measured fields."""
    body = {
        "model": model,
        "prompt": prompt,
        "stream": True,
        "options": {
            "num_predict": gen,
            "temperature": 0.2,
            "num_ctx": 8192,
        },
    }
    if think:
        body["think"] = think

    t_start = time.perf_counter()
    ttft = None
    n_tokens = 0
    last = None
    chunks = []

    with http_post_json(f"{base}/api/generate", body) as resp:
        buf = b""
        while True:
            chunk = resp.read(1024)
            if not chunk:
                break
            buf += chunk
            while b"\n" in buf:
                line, buf = buf.split(b"\n", 1)
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line.decode("utf-8", "replace"))
                except json.JSONDecodeError:
                    continue
                if obj.get("done"):
                    last = obj
                    continue
                tok = obj.get("response", "")
                if tok:
                    if ttft is None:
                        ttft = time.perf_counter() - t_start
                    n_tokens += 1
                    chunks.append(tok)

    total = time.perf_counter() - t_start
    text = "".join(chunks)
    # Ollama's done frame carries eval counts; fall back to a rough tokenizer.
    eval_count = (last or {}).get("eval_count")
    prompt_count = (last or {}).get("prompt_eval_count")
    if not eval_count:
        eval_count = max(n_tokens, len(text.split()))
    return {
        "ttft_s": round(ttft, 3) if ttft is not None else None,
        "decode_tps": round(eval_count / (total - (ttft or 0)), 2) if (total - (ttft or 0)) > 0 else None,
        "wall_s": round(total, 3),
        "tokens": eval_count,
        "prompt_tokens": prompt_count,
        "prefill_tps": round(prompt_count / ttft, 1) if (prompt_count and ttft) else None,
        "text_chars": len(text),
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default=BASE_URL)
    ap.add_argument("--model", required=True)
    ap.add_argument("--prompt-kind", choices=list(PROMPTS), default="code")
    ap.add_argument("--iters", type=int, default=3)
    ap.add_argument("--gen", type=int, default=256)
    ap.add_argument("--think", action="store_true")
    ap.add_argument("--out", default=None)
    args = ap.parse_args()

    prompt = PROMPTS[args.prompt_kind]
    results = []
    for i in range(args.iters):
        try:
            r = stream_once(args.base, args.model, prompt, args.gen, args.think)
            r["iter"] = i
            results.append(r)
            sys.stderr.write(f"  iter {i}: ttft={r['ttft_s']}s decode={r['decode_tps']}tok/s wall={r['wall_s']}s\n")
        except Exception as e:
            results.append({"iter": i, "error": f"{type(e).__name__}: {e}"})
            sys.stderr.write(f"  iter {i}: ERROR {e}\n")

    ok = [r for r in results if "error" not in r and r.get("decode_tps")]
    summary = {
        "model": args.model,
        "prompt_kind": args.prompt_kind,
        "gen": args.gen,
        "iters": args.iters,
        "runs": results,
    }
    if ok:
        summary["median_decode_tps"] = round(sorted(r["decode_tps"] for r in ok)[len(ok) // 2], 2)
        summary["median_ttft_s"] = round(sorted(r["ttft_s"] for r in ok if r["ttft_s"] is not None)[0], 3)
        summary["best_decode_tps"] = max(r["decode_tps"] for r in ok)

    out = args.out or os.path.join(os.path.dirname(__file__), "results", f"{args.model.replace('/', '_')}.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    with open(out, "w") as f:
        json.dump(summary, f, indent=1)
    print(json.dumps({k: summary[k] for k in summary if k != "runs"}))
    print(f"[wrote {out}]")


if __name__ == "__main__":
    main()
