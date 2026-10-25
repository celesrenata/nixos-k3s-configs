# ArcForge rerank slice for gremlin-2.
#
# Enables the host-native Qwen3-Reranker service on the PF render node
# (port 8101) alongside the embedding service (port 8100). The shared,
# host-agnostic values live in the module directory.
{ imports = [ ../../modules/services/arcforge/rerank-slice.nix ]; }
