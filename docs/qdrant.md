# Qdrant Retrieval: Quantization Comparison, GPU Indexing, and Sidecar

Date: 2026-10-24 (Sat)
Status: COMPLETE — §6 quantization comparison + §11 baselines run on
disposable collections; 1.20.0 TurboQuant sidecar deployed as a persistent
systemd service on gremlin-1; §7 GPU indexing recipe + go/no-go documented
(source build blocked on toolchain, by design).

Implements ArcForge plan sections §6 (Qdrant quantization comparison),
§11 (baselines before replacing anything), and §7 (experimental GPU
indexing, recipe only — no build this phase).

## As-is (what was live before this work)

Qdrant 1.15.5 runs host-native on gremlin-1 (`10.1.1.12:6333` REST /
`6334` gRPC), deployed from `hosts/gremlin-1/qdrant.nix` via the
nixpkgs-**stable** channel (the unstable nixpkgs qdrant 1.18.2 fails to
build on this host — AVX512-VNNI intrinsic `llvm.x86.avx512.vpdpbusd.512`
mismatch in rustc 1.98; see "Why release binary" below).

Live collections (verified, read-only — never modified):

| collection | points | dims | distance | notes |
|---|---|---|---|---|
| `omniroute_memory` | 25 | 1024 | Cosine | OmniRoute memory engine |
| `ws-b6528982be5d5164` | 7,600 | 1024 | Cosine | m=64, ef_construct=512, vectors+HNSW+payload `on_disk`, `indexing_threshold=20000`, `quantization_config: null` |

Key finding on the production ws- collection: `indexed_vectors_count=0`
because 7,600 < `indexing_threshold` 20,000, so **production retrieval is
currently exact full-scan** (no HNSW index built). This is the baseline
every quantization candidate must not regress.

## Version capability matrix (live-verified, both versions)

Verified against the running 1.15.5 (6333) and 1.20.0 (6433):

| capability | 1.15.5 | 1.20.0 |
|---|---|---|
| create collection | `PUT /collections/{name}` | `PUT /collections/{name}` |
| upsert points | `PUT /points` (`{"points":[...]}`) | `PUT /points` |
| scalar int8 / binary quantization | ✓ | ✓ |
| TurboQuant (`quantization_config.turbo`) | ✗ 400 (untagged enum) | ✓ `bits1/bits1_5/bits2/bits4/bits8` |
| lossy-only datatype (`vectors.datatype`) | ✗ | ✓ `turbo4/turbo8/turbo16` (plus `uint8/float16`) |
| per-search rescoring (`params.quantization.rescore`) | ✓ | ✓ |
| exact search via high `full_scan_threshold` | ✓ | ✓ |
| `hnsw_ef_search` search param | ✓ | ✓ |
| `/metrics` (unprefixed: `memory_allocated_bytes`, …) | ✓ | ✓ |

API notes (verified live):
- **Create = `PUT /collections/{name}` on both versions.** `POST
  /collections/{name}` returns a content-length-0 **404** (route absent).
- **1.20.0 upsert break:** `POST /points` now takes a new `PointRequest`
  schema and 400s on the classic shape (`"missing field ids"`). Use
  `PUT /points` with `{"points":[...]}` — works on **both** versions.
- **Rescore param shape (both versions):** `params` =
  `{"hnsw_ef_search": N, "quantization": {"rescore": true}}`.
  `params.quantization` is an **object** (`{ignore, rescore, oversampling}`),
  **not** a bool. 1.20.0 additionally accepts `hnsw_ef` and a flat
  `params.rescore`.
- **1.15.5 cannot set quantization post-create:** `PUT
  /collections/{name}/quantization/config` → 404. Quantization must be
  passed at creation time.
- Metric names are unprefixed in both (`memory_allocated_bytes`,
  `memory_active_bytes`), not `qdrant_*`.

## TurboQuant on 1.20.0 (verified live)

Three distinct shapes, each with different storage/precision trade-offs:

| shape | API | originals kept | rescoring | disk (2000×1024) | recall@10 |
|---|---|---|---|---|---|
| **Quantization layer** | `quantization_config: {"turbo":{"bits":"bits4"}}` | ✓ | ✓ | 31.4 MiB | 0.9688 (raw) / 0.9917 (rescore) |
| **Lossy-only datatype** | `vectors.datatype: "turbo4"` | ✗ | ✗ | **11.4 MiB** | 0.9604 |
| (no quantization) | — | — | — | 28.6 MiB (fp32) | 0.9979 |

- The **layer** keeps originals and enables per-search full-precision
  rescoring (`params.quantization.rescore=true`) — the recommended default.
- **`turbo4dtype`** (lossy-only) stores only the 4-bit representation:
  `indexed_vectors_count` never increments (the counter is untracked for a
  lossy-only datatype), readiness must be judged by
  `points_count + status: green + optimizer_status: ok`. It saves
  **~60% disk** vs fp32 but loses rescoring (no originals).

## Benchmark methodology

Harness: `bench/qdrant_retrieval_bench.py` (stdlib-only Python, JSON out,
one-line summary). Design:

1. **Corpus** — real 1024-dim vectors scrolled read-only (`POST /scroll`)
   from the live `ws-b6528982be5d5164` on production. Nothing is written to
   production.
2. **Ground truth** — an exact full-scan reference collection on the **same
   instance** (`full_scan_threshold` > corpus size → brute-force exact
   top-k), not Python-side brute force. This keeps ground truth
   version-consistent with the variant being tested.
3. **HNSW mirrors production** — `m=64`, `ef_construct=512`,
   `indexing_threshold=512` (forces the index to build on the small corpus).
4. Per-variant measurement: ingestion throughput (pts/s), index build time
   (upsert-complete → indexed), recall@5/10 vs exact, p50/p95/p99 search
   latency, payload-filter correctness (range filters on synthetic payload),
   8-worker concurrent-read throughput, real disk (`du -s --block-size=1`,
   ignoring Qdrant's sparse preallocated segment/WAL sizes), process-memory
   delta (`/metrics`).
5. **Acceptance gate (§11):** recall@10 ≥ 98% of the full-precision
   baseline. All test collections use the `qdrant-bench-` prefix and are
   **dropped at the end**; production collections are never touched.
6. Params: 2000-pt corpus (1.20.0) / 1500-pt corpus (1.15.5), 48 queries,
   seed 1337, `ef_search=10`.

**Production safety:** after both runs, the production instance shows
exactly its original 2 collections; the sidecar shows 0.

## Results

### Qdrant 1.20.0 (sidecar, 6433 — 2000-pt corpus)

| variant | recall@5 | recall@10 | p50 | p95 | p99 | build (s) | ingest (pts/s) | disk (MiB) | filter | gate (≥98% fp) |
|---|---|---|---|---|---|---|---|---|---|---|
| fp (baseline) | 1.0000 | **0.9979** | 1.17ms | 1.47ms | 1.52ms | 0.21 | 2344 | 28.6 | 200/0 viol | — |
| int8 | 0.9458 | 0.8937 | 1.20ms | 1.92ms | 2.38ms | 0.20 | 2343 | 31.0 | 200/0 | ✗ (0.90×) |
| int8-rescore | 1.0000 | 0.9875 | 1.03ms | 1.65ms | 1.92ms | 0.21 | 2372 | 31.0 | 200/0 | ✓ (0.99×) |
| turbo4 | 1.0000 | 0.9688 | 1.10ms | 1.33ms | 1.46ms | 0.20 | 2248 | 31.4 | 200/0 | ✗ (0.97×) |
| turbo4-rescore | 1.0000 | 0.9917 | 1.05ms | 1.30ms | 1.43ms | 0.20 | 2297 | 31.4 | 200/0 | **✓ (0.99×)** |
| turbo4dtype | 0.9958 | 0.9604 | 1.11ms | 1.59ms | 1.86ms | 0.00* | 2343 | **11.4** | 187/0 | ✗ (0.96×) |

\* `turbo4dtype` reports `indexed_vectors_count=0` forever (counter untracked
for lossy-only datatype); the "build" time is just upsert→green, not a real
HNSW build.

**Gate outcomes (1.20.0):** `int8-rescore` and `turbo4-rescore` **pass** the
§11 gate (≥98% of fp recall@10); raw `int8`, `turbo4`, and `turbo4dtype`
**fail**. Raw int8 is the weakest (0.894); TurboQuant without rescoring is
competitive (0.969) and only loses to int8 when int8 is also rescored.

### Qdrant 1.15.5 (production instance, 6333 — 1500-pt corpus)

| variant | recall@5 | recall@10 | p50 | p95 | p99 | build (s) | ingest (pts/s) | disk (MiB) | filter | gate (≥98% fp) |
|---|---|---|---|---|---|---|---|---|---|---|
| fp (baseline) | 1.0000 | **0.9979** | 1.09ms | 1.66ms | 2.00ms | 0.61 | 2273 | 14.0 | 190/0 viol | — |
| int8 | 0.9458 | 0.9000 | 1.13ms | 1.39ms | 1.70ms | 0.61 | 2288 | 15.5 | 192/0 | ✗ (0.90×) |
| int8-rescore | 1.0000 | 0.9958 | 1.14ms | 2.52ms | 3.01ms | 0.61 | 2318 | 15.5 | 200/0 | **✓ (0.998×)** |

(1.15.5 has no TurboQuant — the layer and datatype are 1.18+/1.19+ features.)

**Gate outcomes (1.15.5):** `int8-rescore` **passes**; raw `int8` **fails**.
Rescoring is what recovers recall to ~full-precision on both versions.

### Cross-version notes

- fp recall@10 is identical (0.9979) on both — the corpus + ground-truth
  methodology reproduces exactly.
- Rescoring behaves the same on both: it lifts int8 from ~0.90 to ~0.99.
- 1.15.5 int8-rescore has higher p95 (2.5ms) than 1.20.0 int8-rescore
  (1.65ms); the 1.20.0 rescoring path is faster.
- Production ws- is full-scan today (7,600 < 20,000 threshold). Once it
  crosses the threshold, HNSW engages — the quantization decision below
  applies at that point.

## Recommendation

- **Default candidate: TurboQuant 4-bit quantization layer with rescoring
  (`quantization_config: {"turbo":{"bits":"bits4"}}` + per-search
  `params.quantization.rescore=true`).** It passes the §11 gate
  (recall@10 0.9917 = 99.4% of fp), is the **lowest-latency** variant that
  passes (p50 1.05ms / p95 1.30ms — faster than even the fp baseline),
  keeps originals (so no data loss and rescoring available), and is the
  forward-looking feature (only on 1.18+/1.20). It requires the 1.20.0
  sidecar, so adopting it means moving retrieval to the 1.20.0 instance.
- **Fallback / conservative: scalar int8 with rescoring.** Passes the gate
  on **both** 1.15.5 and 1.20.0, so it is the lowest-risk option if we
  cannot migrate off 1.15.5. Slightly higher latency than turbo4-rescore.
- **Not recommended without rescoring:** raw int8 (worst recall, 0.89–0.90),
  raw turbo4 (0.969, just under gate).
- **`turbo4dtype` (lossy-only):** best disk (11.4 MiB, ~60% less than fp32),
  acceptable recall (0.960) but **no rescoring** and untracked index
  counters — use only if disk is the binding constraint and a ~4% recall
  loss is acceptable. Disposable-collection-only per spec; never convert
  production to lossy-only without explicit sign-off.

Machine-readable results: `bench/results/qdrant-bench-120.json` and
`bench/results/qdrant-bench-115.json`.

## TurboQuant unblock recipe (why the sidecar, and how it works)

Production is 1.15.5, which **cannot** do TurboQuant (400 on the `turbo`
enum). nixpkgs-unstable qdrant (1.18.2) fails to build on this host
(AVX512-VNNI intrinsic), and the 1.20.0 **source** build (needed for §7 GPU
HNSW) has the same LLVM/rustc blocker. The only viable 1.18+ source on this
host is the **official prebuilt release binary**.

- The official **gnu** tarball is dynamically linked → fails on NixOS
  (`nixos-stub-ld` linker stub). The **musl** tarball is a static single
  binary that runs as-is (no runtime closure).
- Deployed as a **sidecar systemd service** via the opt-in module
  `modules/services/qdrant-turbo.nix`, enabled on gremlin-1 in
  `hosts/gremlin-1/qdrant-turbo.nix`:
  - Binds `10.1.1.12:6433` (REST) / `6434` (gRPC).
  - Its own state directory `/var/lib/qdrant-turbo` (separate from
    production `/var/lib/qdrant`).
  - Its own user/group `qdrant-turbo`; firewall allows 6433 on this host
    only (production 6333 stays scoped by `qdrant.nix`).
  - SHA-256-pinned v1.20.0 musl archive; `package` option overridable to
    point at a locally built binary (e.g. a `--features gpu` source build)
    without re-wiring the service.
- **Production 1.15.5 on 6333 is untouched.** The two instances coexist.

Rollback: `services.qdrant-turbo.enable = false` + rebuild removes the
sidecar; production is unaffected at any point (separate binary, state dir,
user, ports).

## §7 Experimental GPU indexing — recipe + go/no-go

Goal: validate Qdrant GPU (Vulkan) HNSW indexing on the Intel Arc PF vs the
CPU HNSW baseline, in a **separate experimental environment** with an
explicit Intel PF device and a single indexing process. **Not built this
phase** (deferred by design) because the GPU feature is source-build-only.

### Why the release binary can't do it
The v1.20.0 **prebuilt** release binary contains **zero Vulkan symbols** —
GPU HNSW is gated behind the Rust `gpu` feature and is only present in a
source build with `--features gpu` + a Vulkan 1.3 runtime. (The settings
struct has `GpuConfig` fields — `gpu_devices`, `device_filter`,
`allow_emulated`, `groups_count` — but they are inert without the feature.)

### Build recipe (for when the toolchain allows it)
```bash
# Prereqs: Vulkan 1.3 runtime on the host (lavapipe / ICD loader +
# vulkan-1.3), Rust stable. On this host the blocker is rustc 1.98 /
# bundled LLVM < 22 emitting llvm.x86.avx512.vpdpbusd.512 — needs LLVM >= 22.
cargo build --release --features gpu
```
Then point the sidecar at it via the module override (no service rewiring):
```nix
services.qdrant-turbo.package = myGpuQdrantBuild;   # a nixpkgs/cargo derivation
```
Enable GPU in the config (settings) with an explicit PF device and one
indexing process:
```yaml
gpu:
  enabled: true
  gpu_devices: [0]          # the Intel Arc PF (single explicit device)
  allow_emulated: false      # force real PF, no CPU/emulated fallback
  # single indexing process — do not run more than one index build at a time
```

### Go/no-go vs CPU HNSW (acceptance criteria)
Run the same `bench/qdrant_retrieval_bench.py` matrix against a
GPU-indexed collection on the experimental instance, and compare:

| metric | CPU HNSW baseline | GPU target | go condition |
|---|---|---|---|
| index build time | measured | measured | **build ≥2× faster** on GPU |
| recall@10 vs fp | 0.9979 (must match) | must match | recall@10 ≥ 98% of fp (same §11 gate) |
| p95 search latency | measured | measured | no regression >10% |
| memory/disk | measured | measured | no unbounded growth |

**GO** if GPU build is ≥2× faster **and** recall/latency are not worse than
CPU HNSW **and** the single-PF device policy holds (closed device policy —
the GPU must open only the PF render node, no silent CPU fallback).
**NO-GO** otherwise (fall back to CPU HNSW; TurboQuant/rescore decision is
independent of GPU indexing and still stands).

Because the toolchain blocker (LLVM ≥22 / AVX512) is a host limitation, this
is deferred until a build environment with the required LLVM is available.
The recipe above is ready to run unchanged once that is true.

## Cutover / rollback

- **Nothing in this phase replaces production.** The quantization
  comparison, baselines, and sidecar are all additive/disposable.
- **Cutover (future, separate decision):** to adopt turbo4-rescore, migrate
  retrieval traffic to the 1.20.0 sidecar (6433) and re-create the
  production collection there with the TurboQuant layer + rescoring —
  a planned operation, not part of this work.
- **Rollback is trivial at every step:** the sidecar is opt-in and
  isolated; disabling it leaves production 1.15.5/6333 exactly as it was.
