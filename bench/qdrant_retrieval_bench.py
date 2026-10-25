#!/usr/bin/env python3
"""Qdrant retrieval benchmark: quantization comparison with exact ground truth.

Implements the ArcForge spec section 6 (Qdrant quantization comparison tests)
and section 11 (baselines) on a disposable collection only:

  1. Reads a corpus of real vectors (default: the live ws- repository
     collection on the production instance, read-only).
  2. Creates a throwaway collection per variant on the target instance,
     ingests the corpus, and forces the HNSW index to build.
  3. Builds an exact full-scan reference collection (ground truth top-k) on
     the same corpus.
  4. For each variant measures:
        - ingestion throughput (pts/s)
        - index build time (upsert-complete -> indexed)
        - recall@5 / recall@10 vs exact ground truth
        - p50/p95/p99 search latency (per-query round trip)
        - payload-filter correctness (range filters on synthetic payload)
        - concurrent-read throughput (8 workers)
        - disk usage of the collection (best effort)
        - process memory delta (best effort, from /metrics)
  5. Writes a machine-readable JSON report + a one-line summary.

Variants (auto-selected by Qdrant version reported by GET /):
  fp            no quantization            (always)
  int8          scalar int8 quantization   (always; 1.15+)
  int8-rescore  scalar int8 + per-search full-precision rescoring (1.15+)
  turbo4        TurboQuant 4-bit quantization layer, originals kept (1.18+)
  turbo4-rescore TurboQuant 4-bit + rescoring                      (1.18+)
  turbo4dtype   turbo4 datatype: lossy-only storage, NO originals  (1.19+)
                (spec: disposable collections only, never production)

All test collections are dropped at the end unless --keep is given.
Production collections are never modified (read-only scroll from the source).

Usage:
  python3 qdrant_retrieval_bench.py \
      --base http://127.0.0.1:6433 \
      --source-base http://10.1.1.12:6333 \
      --source-collection ws-b6528982be5d5164 \
      --corpus-size 3000 --queries 48 --ef-search 10 \
      --out results/qdrant-bench.json

Only the Python standard library is used.
"""

import argparse
import concurrent.futures
import json
import os
import random
import subprocess
import sys
import time
import urllib.error
import urllib.request

PREFIX = "qdrant-bench-"
UP_BATCH = 256
FILTER_CHECKS = 10
FILTER_K = 20
CONCURRENCY = 8
CONCURRENT_QUERIES = 240
WARMUP = 3


def http_json(url, payload=None, method=None, timeout=600):
    """Return (status_code, parsed_json). Raises on network failure only."""
    data = None
    headers = {}
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers = {"Content-Type": "application/json"}
    req = urllib.request.Request(url, data=data, headers=headers,
                                 method=method or ("POST" if data is not None else "GET"))
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status, json.loads(resp.read().decode("utf-8", "replace"))
    except urllib.error.HTTPError as e:
        try:
            body = json.loads(e.read().decode("utf-8", "replace"))
        except Exception:
            body = {"status": {"error": e.reason}}
        return e.code, body


def version_tuple(v):
    try:
        parts = v.split(".")
        return (int(parts[0]), int(parts[1]), int(parts[2] if len(parts) > 2 else 0))
    except (ValueError, IndexError):
        return (0, 0, 0)


def scroll_source(base, collection, limit):
    """Read up to `limit` points (id, vector, payload) from the source collection."""
    points = []
    offset = None
    page = 500
    while len(points) < limit:
        body = {"limit": page, "with_vectors": True, "with_payload": True}
        if offset is not None:
            body["offset"] = offset
        code, resp = http_json(f"{base}/collections/{collection}/points/scroll", body, "POST")
        if code != 200:
            raise RuntimeError(f"scroll failed: {resp}")
        pts = resp["result"]["points"]
        if not pts:
            break
        for p in pts:
            points.append(p)
            if len(points) >= limit:
                break
        offset = resp["result"].get("next_page_offset")
        if offset is None:
            break
    return points


def create_collection(base, name, dim, variant, m, ef_construct, indexing_threshold):
    t0 = time.perf_counter()
    vectors = {"size": dim, "distance": "Cosine"}
    if variant == "turbo4dtype":
        vectors["datatype"] = "turbo4"
    body = {
        "vectors": vectors,
        "hnsw_config": {"m": m, "ef_construct": ef_construct,
                        "full_scan_threshold": 10000},
        "optimizer_config": {"indexing_threshold": indexing_threshold,
                             "full_scan_threshold": 10000},
    }
    if variant in ("int8", "int8-rescore"):
        body["quantization_config"] = {"scalar": {"type": "int8"}}
    elif variant in ("turbo4", "turbo4-rescore"):
        body["quantization_config"] = {"turbo": {"bits": "bits4"}}
    code, resp = http_json(f"{base}/collections/{name}", body, "PUT")
    create_ms = (time.perf_counter() - t0) * 1000.0
    if code != 200:
        raise RuntimeError(f"create_collection failed ({code}): {resp}")
    return create_ms


def ingest(base, name, points):
    """Upsert all points in batches (PUT /points is stable across 1.15-1.20);
    returns (seconds, pts_per_s)."""
    t0 = time.perf_counter()
    sent = 0
    for i in range(0, len(points), UP_BATCH):
        batch = [{"id": idx + i, "vector": p["vector"], "payload": p["payload"]}
                 for idx, p in enumerate(points[i:i + UP_BATCH])]
        code, resp = http_json(f"{base}/collections/{name}/points?wait=true",
                               {"points": batch}, "PUT")
        if code != 200:
            raise RuntimeError(f"upsert failed ({code}): {resp}")
        sent += len(batch)
    secs = time.perf_counter() - t0
    return secs, (sent / secs if secs > 0 else 0.0)


def wait_indexed(base, name, expected, lossy=False, timeout=600):
    """Wait until the collection is green and searchable.

    Returns (seconds, indexed_vectors_count, points_count).

    For lossy-only datatype collections (turbo4dtype) 1.20.0 never updates
    indexed_vectors_count (stays 0), so readiness is points_count + status.
    """
    t0 = time.perf_counter()
    while time.perf_counter() - t0 < timeout:
        code, resp = http_json(f"{base}/collections/{name}")
        if code == 200:
            r = resp["result"]
            status = r.get("status", "?")
            opt = r.get("optimizer_status", "?")
            indexed = r.get("indexed_vectors_count", 0)
            pts = r.get("points_count", 0)
            ready = pts >= expected and status == "green" and opt == "ok"
            if not lossy:
                ready = ready and indexed >= expected
            if ready:
                return time.perf_counter() - t0, indexed, pts
        time.sleep(0.2)
    code, resp = http_json(f"{base}/collections/{name}")
    r = resp.get("result", {}) if code == 200 else {}
    return (time.perf_counter() - t0,
            r.get("indexed_vectors_count", -1),
            r.get("points_count", -1))


def search(base, name, vector, k, params):
    body = {"vector": vector, "limit": k, "with_payload": False}
    if params:
        body["params"] = params
    t0 = time.perf_counter()
    code, resp = http_json(f"{base}/collections/{name}/points/search", body, "POST")
    dt = (time.perf_counter() - t0) * 1000.0
    if code != 200:
        raise RuntimeError(f"search failed ({code}): {resp}")
    return [h["id"] for h in resp["result"]], dt


def percentile(sorted_xs, p):
    if not sorted_xs:
        return None
    idx = min(len(sorted_xs) - 1, int(round(p / 100.0 * (len(sorted_xs) - 1))))
    return sorted_xs[idx]


def read_metrics(base):
    try:
        req = urllib.request.Request(base + "/metrics")
        with urllib.request.urlopen(req, timeout=10) as resp:
            text = resp.read().decode("utf-8", "replace")
    except Exception:
        return {}
    out = {}
    for line in text.splitlines():
        if line.startswith("#") or not line:
            continue
        key, _, val = line.partition(" ")
        if "memory_allocated_bytes" == key:
            out["memory_allocated_bytes"] = float(val)
        elif "memory_active_bytes" == key:
            out["memory_active_bytes"] = float(val)
    return out


def disk_bytes(storage_path, name):
    if not storage_path:
        return None
    p = os.path.join(storage_path, "collections", name)
    if not os.path.isdir(p):
        return None
    try:
        # --block-size=1 without -b (=-apparent-size): real blocks allocated,
        # ignoring Qdrant's preallocated (sparse) segment/WAL file sizes.
        out = subprocess.run(["du", "-s", "--block-size=1", p],
                             capture_output=True, timeout=30)
        return int(out.stdout.split()[0])
    except Exception:
        return None


def filter_checks(base, name, n_points, rng, corpus_vectors):
    """Run random range-filter searches; verify every hit satisfies the filter."""
    violations = 0
    checked = 0
    for _ in range(FILTER_CHECKS):
        lo = rng.randrange(0, max(1, n_points - 200))
        hi = lo + rng.randrange(10, 200)
        hi = min(hi, n_points)
        vector = corpus_vectors[rng.randrange(len(corpus_vectors))]
        body = {
            "vector": vector,
            "limit": FILTER_K,
            "with_payload": True,
            "filter": {"must": [{"key": "idx", "range": {"gte": lo, "lt": hi}}]},
        }
        code, resp = http_json(f"{base}/collections/{name}/points/search", body, "POST")
        if code != 200:
            violations += 1
            continue
        for h in resp["result"]:
            checked += 1
            idx = (h.get("payload") or {}).get("idx")
            if idx is None or not (lo <= idx < hi):
                violations += 1
    return checked, violations


def run_variant(base, vname, points, query_vectors, ef, m, ef_construct,
                storage_path, drop=True, timeout=600):
    n = len(points)
    name = PREFIX + vname
    # drop any stale collection from a previous run
    http_json(f"{base}/collections/{name}", method="DELETE", timeout=30)
    create_ms = create_collection(base, name, len(points[0]["vector"]), vname,
                                  m, ef_construct, indexing_threshold=512)
    try:
        mem_before = read_metrics(base)
        ingest_secs, pts_per_s = ingest(base, name, points)
        build_secs, indexed, _ = wait_indexed(base, name, n,
                                               lossy=(vname == "turbo4dtype"),
                                               timeout=timeout)
        mem_after = read_metrics(base)

        params = {"hnsw_ef_search": ef}
        if vname in ("int8-rescore", "turbo4-rescore"):
            params["quantization"] = {"rescore": True}

        # warmup
        for v in query_vectors[:WARMUP]:
            search(base, name, v, 10, params)

        latencies_ms = []
        ids_per_query = {}
        for i, v in enumerate(query_vectors):
            ids, dt = search(base, name, v, 10, params)
            latencies_ms.append(dt)
            ids_per_query[i] = ids

        srt = sorted(latencies_ms)
        stats = {
            "n": len(latencies_ms),
            "p50_ms": round(percentile(srt, 50), 3),
            "p95_ms": round(percentile(srt, 95), 3),
            "p99_ms": round(percentile(srt, 99), 3),
            "mean_ms": round(sum(latencies_ms) / len(latencies_ms), 3),
        }

        rng = random.Random(1337 + len(vname))
        checked, violations = filter_checks(base, name, n, rng, query_vectors)

        # concurrent reads
        c_lat = []

        def worker(idx):
            _, dt = search(base, name, query_vectors[idx % len(query_vectors)], 10, params)
            return dt

        t0 = time.perf_counter()
        with concurrent.futures.ThreadPoolExecutor(CONCURRENCY) as ex:
            for dt in ex.map(worker, range(CONCURRENT_QUERIES)):
                c_lat.append(dt)
        wall = time.perf_counter() - t0
        c_srt = sorted(c_lat)
        conc = {
            "workers": CONCURRENCY,
            "requests": len(c_lat),
            "qps": round(len(c_lat) / wall, 1),
            "p50_ms": round(percentile(c_srt, 50), 3),
            "p95_ms": round(percentile(c_srt, 95), 3),
        }

        out = {
            "collection": name,
            "create_ms": round(create_ms, 1),
            "ingest_seconds": round(ingest_secs, 2),
            "ingest_pts_per_s": round(pts_per_s, 1),
            "index_build_seconds": round(build_secs, 2),
            "indexed_vectors": indexed,
            "points": n,
            "search": stats,
            "filter_correctness": {"checks": FILTER_CHECKS, "hits_checked": checked,
                                    "violations": violations},
            "concurrent_reads": conc,
            "disk_bytes": disk_bytes(storage_path, name),
            "memory_allocated_bytes": {
                "before": mem_before.get("memory_allocated_bytes"),
                "after": mem_after.get("memory_allocated_bytes"),
            },
        }
        return out, ids_per_query
    finally:
        if drop:
            http_json(f"{base}/collections/{name}", method="DELETE", timeout=60)


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--base", required=True, help="target Qdrant base URL")
    ap.add_argument("--source-base", default=None,
                    help="Qdrant instance holding the source collection (default: --base)")
    ap.add_argument("--source-collection", default="ws-b6528982be5d5164")
    ap.add_argument("--corpus-size", type=int, default=3000)
    ap.add_argument("--queries", type=int, default=48)
    ap.add_argument("--seed", type=int, default=1337)
    ap.add_argument("--m", type=int, default=64)
    ap.add_argument("--ef-construct", type=int, default=512)
    ap.add_argument("--ef-search", type=int, default=10)
    ap.add_argument("--keep", action="store_true",
                    help="do not drop test collections at the end")
    ap.add_argument("--storage-path", default=None,
                    help="qdrant storage dir on this host (disk usage, best effort)")
    ap.add_argument("--out", default=None, help="JSON output path")
    args = ap.parse_args()

    source_base = args.source_base or args.base

    code, root = http_json(args.base + "/", timeout=15)
    if code != 200:
        sys.exit(f"target qdrant not reachable: {code} {root}")
    version = root.get("version", "unknown")
    vt = version_tuple(version)

    variants = ["fp", "int8", "int8-rescore"]
    if vt >= (1, 18, 0):
        variants += ["turbo4", "turbo4-rescore"]
    if vt >= (1, 19, 0):
        variants += ["turbo4dtype"]

    print(f"target {args.base} qdrant {version} -> variants: {', '.join(variants)}")
    print(f"scrolling {args.corpus_size} points from {source_base}/"
          f"{args.source_collection} ...")
    t0 = time.perf_counter()
    src_points = scroll_source(source_base, args.source_collection, args.corpus_size)
    scroll_secs = time.perf_counter() - t0
    if len(src_points) < 100:
        sys.exit(f"source collection has only {len(src_points)} points; aborting")
    n = len(src_points)
    dim = len(src_points[0]["vector"])

    # assign ids + payloads deterministically
    points = []
    for i, p in enumerate(src_points):
        points.append({
            "id": i,
            "vector": p["vector"],
            "payload": {"idx": i, "src_id": str(p.get("id", ""))},
        })
    print(f"corpus: {n} points x {dim} dims (scroll {scroll_secs:.1f}s)")

    rng = random.Random(args.seed)
    qidx = rng.sample(range(n), min(args.queries, n))
    query_vectors = [points[i]["vector"] for i in qidx]

    # exact ground truth: full-scan reference collection on the same corpus
    exact_name = PREFIX + "exact"
    http_json(f"{args.base}/collections/{exact_name}", method="DELETE", timeout=30)
    t0 = time.perf_counter()
    code, resp = http_json(
        f"{args.base}/collections/{exact_name}",
        {"vectors": {"size": dim, "distance": "Cosine"},
         "hnsw_config": {"full_scan_threshold": n + 100},
         "optimizer_config": {"indexing_threshold": n + 100,
                              "full_scan_threshold": n + 100}},
        method="PUT")
    if code != 200:
        sys.exit(f"exact ref collection create failed: {resp}")
    for i in range(0, n, UP_BATCH):
        batch = [{"id": p["id"], "vector": p["vector"], "payload": p["payload"]}
                 for p in points[i:i + UP_BATCH]]
        code, _ = http_json(f"{args.base}/collections/{exact_name}/points?wait=true",
                            {"points": batch}, method="PUT", timeout=600)
        if code != 200:
            sys.exit(f"exact ref ingest failed: {code}")
    exact_ids = {}
    for i, v in enumerate(query_vectors):
        ids, _ = search(args.base, exact_name, v, 10, {"hnsw_ef_search": 100})
        exact_ids[i] = ids
    exact_keep = args.keep

    results = {
        "meta": {
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "target_base": args.base,
            "qdrant_version": version,
            "source_base": source_base,
            "source_collection": args.source_collection,
            "corpus_size": n,
            "dims": dim,
            "queries": len(query_vectors),
            "seed": args.seed,
            "hnsw": {"m": args.m, "ef_construct": args.ef_construct,
                     "indexing_threshold": 512},
            "ef_search": args.ef_search,
            "ground_truth": "exact full-scan collection, top-10",
        },
        "variants": {},
    }

    try:
        for v in variants:
            print(f"  variant: {v} ...", end=" ", flush=True)
            vt0 = time.perf_counter()
            vres, ids = run_variant(args.base, v, points, query_vectors,
                                    args.ef_search, args.m, args.ef_construct,
                                    args.storage_path, drop=not args.keep)
            # recall vs exact ground truth (ids returned by run_variant)
            r5 = sum(len(set(ids[i][:5]) & set(exact_ids[i][:10])) / 5.0
                     for i in range(len(query_vectors))) / len(query_vectors)
            r10 = sum(len(set(ids[i]) & set(exact_ids[i][:10])) / 10.0
                      for i in range(len(query_vectors))) / len(query_vectors)
            vres["recall"] = {"k5": round(r5, 4), "k10": round(r10, 4)}
            vres["wall_seconds"] = round(time.perf_counter() - vt0, 1)
            results["variants"][v] = vres
            print(f"done in {vres['wall_seconds']}s "
                  f"(recall10={vres['recall']['k10']}, "
                  f"p95={vres['search']['p95_ms']}ms)")
    finally:
        if not exact_keep:
            http_json(f"{args.base}/collections/{exact_name}", method="DELETE", timeout=60)

    # acceptance gates (spec 11): recall@10 >= 98% of the full-precision baseline
    fp10 = results["variants"].get("fp", {}).get("recall", {}).get("k10")
    gates = {}
    if fp10:
        for v, vr in results["variants"].items():
            v10 = vr.get("recall", {}).get("k10")
            if v10 is not None and v != "fp":
                ratio = v10 / fp10 if fp10 > 0 else 0.0
                gates[v] = {
                    "recall10": v10,
                    "fp_baseline_recall10": fp10,
                    "ratio": round(ratio, 4),
                    "pass": ratio >= 0.98,
                }
    results["gates"] = gates
    for v, g in gates.items():
        results["variants"][v]["gate"] = g

    if args.out:
        os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)
        with open(args.out, "w") as f:
            json.dump(results, f, indent=2, sort_keys=True)
        print(f"wrote {args.out}")

    # one-line summary
    def s(v):
        r = results["variants"].get(v, {})
        rec = r.get("recall", {}).get("k10")
        p95 = r.get("search", {}).get("p95_ms")
        return f"{v}:r10={rec if rec is not None else 'n/a'},p95={p95}ms"
    print("SUMMARY " + " | ".join(s(v) for v in variants))


if __name__ == "__main__":
    main()
