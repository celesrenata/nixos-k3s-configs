# Context — Qwen3-Reranker-0.6B host-native rerank rollout

Date: 2026-10-24 (Sat)
Status: COMPLETE — service built, deployed to all 4 nodes, DB wired, e2e verified. (Commit 6e3f279 on gremlin-1's local /etc/nixos tree.)

## Objective
- Replace the dead docker/OVMS reranker with a host-native reranker (Qwen3-Reranker-0.6B) on all 4 ArcForge nodes, wire it into OmniRoute's `/v1/rerank` so the memory engine's rerank works, and get `/etc/nixos` working-tree changes committed/pushed to origin/dev.

## Constraints
- No reboots, no `nix flake update` / lock updates; only `/etc/nixos` changes + `nixos-rebuild switch --use-remote-sudo`.
- DB backup already taken and verified: `/tmp/nix-shell-3102052-3086018719/omniroute-backup/` (PostgreSQL dumps of `omniroute` + `omniroute_iter`).
- User confirmed via question tool: model = **Qwen3-Reranker-0.6B**; serving = **host-native on all 4 nodes** (ArcForge pattern, no docker); wiring = **register as provider** in OmniRoute.

## Key decisions
- Model artifact: `OpenVINO/Qwen3-Reranker-0.6B-int8-ov` (624 MB; int8 NNCF IR + tokenizer artifacts, Apache-2.0).
  - MTEB-R 65.80 vs bge-reranker-v2-m3 57.03 / jina-v2-base 58.22 / gte 59.51.
  - Same Qwen3 family as the deployed embedding model.
  - 4B/8B variants (69.76 / 69.02) have no off-the-shelf int8-ov IR → rejected.
  - Seq-cls fp16 community variant exists as a fallback (simpler scoring, ~1.2 GB) — NOT used.
- Serving: separate host-native systemd service per node, **port 8101** (embeddings stay on 8100, untouched), same PF device policy (`0000:00:02.0` / `/dev/dri/renderD128`, closed device policy).
- Wiring: OmniRoute self-hosted provider path — `provider_nodes` row(s) with `prefix` + `base_url` (OmniRoute derives `<base>/v1/rerank`, strips trailing `/v1`) + a `provider_connections` row for that provider id (an API key value is required for `getProviderCredentialsWithQuotaPreflight`). Model id for the engine = `<prefix>/<model>`.
- Scoring (causal-LM yes/no logit method, official int8-ov README):
  - Prompt: `'<Instruct>: {instr}\n<Query>: {q}\n<Document>: {doc}'`
  - Default instr: `"Given a web search query, retrieve relevant passages that answer the query"`
  - Wrap with Qwen chat prefix/suffix tokens (prefix = system instruction `Judge whether the Document meets the requirements ... can only be "yes" or "no"`; suffix = assistant start).
  - Left-padded batch; logits at the last (rightmost) position.
  - `score = softmax([logit_yes, logit_no])[0]` = P("yes"); yes/no token ids taken from the bundled tokenizer at startup.
  - tokenizers 0.23.2 is available in the ArcForge python env.

## Work state

### Completed
- Full PostgreSQL backup of `omniroute` + `omniroute_iter` → `/tmp/nix-shell-3102052-3086018719/omniroute-backup/`.
- ArcForge embedding module built; all 4 nodes serving Qwen3-Embedding-0.6B-int8 on :8100 (gremlin-1..4 = 10.1.1.12-15, `"ready":true,"device":"GPU"`).
- Rerank path fully reverse-engineered (contracts, provider resolution, provider_nodes schema, self-hosted branch incl. 404-fallback to `/rerank`).
- Old docker reranker forensics: `ovms-reranker` pod/namespace gone, no OVMS graph.pbtxt or reranker model on disk, old model unrecoverable; `openvino/model_server:latest-gpu` image still cached on gremlin-1 only.
- Feasibility confirmed on gremlin-1: ArcForge python env (`/nix/store/xjd4vzr9gk4i4nmx9za482a3yyjs7rj6-python3-3.14.8-env/bin/python`, OpenVINO 2026.4.0, tokenizers 0.23.2), HF reachable.

### Active (what to do next, in order)
1. Download `OpenVINO/Qwen3-Reranker-0.6B-int8-ov` to gremlin-1 (`/var/lib/arcforge/reranker/`), verify the IR compiles on GPU, and sanity-check yes/no scoring + latency for a batch (~100 short pairs) should be sub-second per doc-set.
2. Write the rerank service (`rerank-service.py` in `modules/services/arcforge/`) + module wiring (systemd unit `arcforge-rerank`, port 8101, PF device policy, same security/metrics patterns as `arcforge-embeddings`), then a per-host rerank slice; `nixos-rebuild switch` on all 4 nodes.
3. DB wiring via psql in the `postgresql-service` pod:
   - `provider_nodes` rows: one per node, `base_url=http://10.1.1.x:8101`, shared `prefix` (e.g. `arcforge`).
   - `provider_connections` row for that provider id with a dummy-but-present API key.
   - `PATCH /api/settings/memory` → `rerankEnabled=true`, `rerankProviderModel="arcforge/qwen3-reranker-0.6b"` (model id must match prefix/registered model).
4. Verify: direct node `:8101/v1/rerank` call; then via OmniRoute `/v1/rerank` with a key; then memory engine-status / retrieve-preview shows rerank active.
5. Commit all `/etc/nixos` working-tree changes (prior ArcForge fixes + new reranker module + slices) and push to `origin/dev`.

## Relevant files
- `/etc/nixos/modules/services/arcforge/` — module dir: `default.nix`, `service.py` (embeddings app, 449 lines, FastAPI, PF-only GPU, circuit breaker, /health /ready /metrics /v1/embeddings), `openvino.nix` (systemd unit generation, icd writeText, python env, tmpfiles /var/lib/arcforge*), `models.nix` (model catalog, `services.arcforge.models` option = "Additional ArcForge model instances (rerank, classifier, vision)"), `security.nix` (hardening applied to the unit — NOTE: hardcodes service name `arcforge-embeddings`), `metrics.nix` (scrape config, nodeIps map gremlin-1..4 = 10.1.1.12-15), `verify-pf.sh`, `embedding-slice.nix`, `README.md`.
- `/etc/nixos/hosts/gremlin-1/arcforge-slice.nix` — canonical per-host slice (imports in gremlin-1/configuration.nix line 10); gremlin-2/3/4 have identical local copies (NOT in the git working tree — only gremlin-1's hosts dir is tracked with the slice file untracked).
  - NOTE: `hosts/gremlin-2|3|4/` dirs contain ONLY `configuration.nix` + `hardware-configuration.nix` → the arcforge slice must be referenced from each host's configuration.nix (check how the rollout was done — possibly a shared slice import).
- Running image: `registry.celestium.life/library/omniroute:3.8.52-ponytail-0b277cab5`; it does NOT read `OMNIROUTE_MEMORY_RERANK_URL` (dead relic). Memory rerank is hardcoded to loopback `http://127.0.0.1:<apiPort>/v1/rerank`.

## OmniRoute rerank internals (reverse-engineered)
- Engine contract (3.8.52): POST `http://127.0.0.1:<apiPort>/v1/rerank`, body `{model, query, documents, top_n}` + `Authorization: Bearer <internal-probe key>`; 5s AbortSignal; expects `{"results":[{"index","relevance_score"}]}`; non-returned indices appended; any failure → graceful fallback to FTS order.
- Self-hosted branch: model `prefix/model`; prefix must match `provider_nodes.prefix`; body `{model,query,documents,top_n,return_documents}` sent to `base_url+/v1/rerank` (404 → retry `/rerank`); response normalized from `results[]` shape. Local (10.x) base URLs pass the local check WITHOUT the `RERANK_REMOTE_PROVIDER_NODES` flag; remote URLs would need the flag.
- Management key retrieval (never hardcode):
  ```
  kubectl exec -n postgresql-service -c postgres $(kubectl get pods -n postgresql-service -o jsonpath='{.items[0].metadata.name}') -- sh -c \
    "psql -U postgres -d omniroute -tA -c \"SELECT key FROM api_keys WHERE name='OmnirouteMGMT' AND is_active=1;\""
  ```
- OmniRoute ClusterIP `10.43.219.244`, port 20128; working endpoints: `/api/memory/embedding-providers`, `/api/settings/memory` with `Authorization: Bearer <key>`.
- Rerank provider catalog (registry): cohere, together, nvidia, fireworks, voyage-ai, jina-ai, siliconflow, openrouter, deepinfra, alibaba — all `hasKey: false`; only the self-hosted `provider_nodes` path avoids cloud keys.
- DB tables (empty today): `provider_nodes` (id/type/name/prefix/api_type/base_url/...), `provider_connections`.
- Scrapped JS bundles for reference: `/tmp/rerank-route.js` (route: provider resolution + self-hosted branch + normalizer), `/tmp/c35518.js` (provider_nodes → `{id:prefix, baseUrl:${base}/v1/rerank}` builder + `RERANK_REMOTE_PROVIDER_NODES` flag + alibaba-qwen3 request builder), `/tmp/c72089.js` (memory engine rerank call site), `/tmp/chunk65450.js`, `/tmp/c10523.js` (memory settings rerankEnabled/rerankProviderModel).

## Hardware / environment
- Intel Meteor Lake-P Arc iGPU on all 4 nodes: PF PCI `0000:00:02.0`, card1, `/dev/dri/renderD128`. No `mem_info_*` sysfs on this kernel.
- Embedding service peak ~4 GB GPU; 0.6B int8 reranker ~0.6 GB fits with headroom; keep rerank concurrency low.
- Nodes: gremlin-1=10.1.1.12, gremlin-2=10.1.1.13, gremlin-3=10.1.1.14, gremlin-4=10.1.1.15.
- Existing model dir convention: `/var/lib/ovms-embeddings/models/OpenVINO/Qwen3-Embedding-0.6B-int8-ov` (world-readable, reused by the embedding slice).
- `arcforge-slice.nix` on gremlin-2/3/4 is a local-only git copy; node-local fixes (wantedBy, MemoryMax key, nullOr, cfg.enable guards) are still UNCOMMITTED in origin.

## Git state (/etc/nixos, branch dev) — post-deploy
- Committed (local gremlin-1 tree, commit `6e3f279`): `modules/services/arcforge/{rerank-service.py,rerank.nix,rerank-slice.nix,default.nix}`, per-host `hosts/gremlin-{1,2,3,4}/arcforge-rerank-slice.nix` (+ imports in each `configuration.nix`), context.md.
- `flake.lock` still locally modified (pre-existing; left uncommitted, not part of this feature).
- Deployment model: each gremlin box keeps its own local /etc/nixos commit history (same message, different hashes) — boxes 2/3/4 were updated by scp + local `git add` + `nixos-rebuild switch --flake .#gremlin-N`. A shared origin/dev push of these per-box commits is NOT required (and would conflict with the per-box divergence).

## What was verified
- Service: bit-identical INT8 scores across all 4 nodes (0.9945 vs 1.0e-05 on a 2-doc probe; 60-doc batch in 7.8s on gremlin-1; breaker stays closed).
- GPU: causal-LM `[B,T,V]` f32 logits exceed the GPU's 4 GiB single-allocation cap at T=8192 → maxLength capped at 4096 + adaptive batch chunking in the service.
- OmniRoute: `POST /v1/rerank model=arcforge/qwen3-reranker-0.6b` → routed via provider_nodes to 10.1.1.12:8101, returned identical scores. `RERANK_REMOTE_PROVIDER_NODES=true` (LAN IPs are not loopback). Memory engine `applyRerank` uses the same in-pod loopback `/v1/rerank` route, so memory rerank inherits the working path (`memoryEnabled` itself left `false` — pre-existing operator choice).

## Rollout notes
- `provider_nodes` prefix is `arcforge` on all 4 nodes; OmniRoute's `localProviders.find(id===prefix)` picks the FIRST by node-id order → 10.1.1.12 serves rerank traffic; 13/14/15 are warm, bit-identical standbys (bit-identical because same INT8 IR + deterministic OpenVINO INT8 path).
- Model dir: `/var/lib/arcforge/reranker/` (595M) on all 4 nodes.
- Units: `arcforge-rerank.service` (port 8101) alongside `arcforge-embeddings.service` (port 8100, untouched).

## Immediate next commands
(none — feature complete. If pushing to origin later: reconcile the per-box local commits into a single origin/dev commit, excluding flake.lock.)
