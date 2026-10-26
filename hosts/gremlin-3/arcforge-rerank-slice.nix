{ config, lib, pkgs, ... }:

# ArcForge rerank slice — shared, host-agnostic concrete values.
#
# Every Meteor Lake render node in this cluster has the same topology:
#   PF = PCI 0000:00:02.0 = card1 = /dev/dri/renderD128
#
# Each render node imports this module to enable the host-native Qwen3-Reranker
# on a dedicated port (8101) alongside the embedding service (8100), both on the
# same PF render node under a closed device policy. The OmniRoute memory engine
# reaches it through the self-hosted provider_nodes path (model id
# "arcforge/qwen3-reranker-0.6b").
{
  services.arcforge-rerank = {
    enable = true;

    # Dedicated port, separate from embeddings (8100).
    port = 8101;
    bindAddress = "0.0.0.0";

    # Deterministic PF selection (same device policy as the embedding slice).
    device = {
      renderNode = "/dev/dri/renderD128";
      pciAddress = "0000:00:02.0";
    };

    # INT8 OpenVINO IR (NNCF Qwen3-Reranker-0.6B).
    model = {
      dir = "/var/lib/arcforge/reranker";
      name = "qwen3-reranker-0.6b";
      version = "qwen3-reranker-0.6b-int8";
      maxLength = 4096;
      padId = 151643;
    };

    # 4 concurrent infer workers, each bound to the PF GPU (no CPU fallback).
    inference = {
      concurrency = 4;
      batchLimit = 64;
      inferTimeoutSec = 60;
    };

    # (Firewall: the shared rerank.nix module opens the port centrally,
    # mirroring how default.nix opens the embedding port.)
  };
}
