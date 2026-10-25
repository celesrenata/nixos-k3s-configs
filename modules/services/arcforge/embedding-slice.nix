{ config, lib, pkgs, ... }:

# ArcForge embedding slice — shared, host-agnostic concrete values.
#
# Every Meteor Lake render node in this cluster has the same topology:
#   PF   = PCI 0000:00:02.0 = card1 = /dev/dri/renderD128
#   IR   = /var/lib/ovms-embeddings/models/OpenVINO/Qwen3-Embedding-0.6B-int8-ov
#
# Each render node imports this module to enable the host-native ArcForge
# embedding service on a dedicated port (8100). That port coexists with the
# proven podman OVMS endpoint (8000) for A/B validation; once cutover is done,
# the consumer (OmniRoute) is pointed at the native 8100 port and the OVMS pod
# can be retired.
#
# The slice reads the proven, world-readable OVMS-extracted IR from
# /var/lib/ovms-embeddings/models (read-only) rather than re-pulling, so it is
# byte-identical to the endpoint it must match.

let
  provenModelDir = "/var/lib/ovms-embeddings/models/OpenVINO/Qwen3-Embedding-0.6B-int8-ov";
in
{
  services.arcforge = {
    enable = true;

    # Dedicated canary port so the proven podman OVMS (8000) stays live for
    # A/B comparison. After validation this becomes the production port.
    port = 8100;
    bindAddress = "0.0.0.0";

    # Deterministic PF selection. Verified at activation against the PCI
    # address (fail loudly if the topology ever changes).
    device = {
      renderNode = "/dev/dri/renderD128";
      pciAddress = "0000:00:02.0";
    };

    model = {
      dir = provenModelDir;
      xml = "${provenModelDir}/openvino_model.xml";
      tokenizer = "${provenModelDir}/tokenizer.json";
      name = "qwen3-embedding-0.6b";
      version = "qwen3-embedding-0.6b-int8";
      dim = 1024;
      maxLength = 4096;   # matches the proven OVMS token ceiling (FEAT-003)
      normalize = "l2";
      padId = 0;
    };

    inference = {
      concurrency = 4;
      batchLimit = 32;
      inferTimeoutSec = 120;
    };

    # Bounded GPU-fault recovery (one restart via watchdog; no reset storm).
    watchdogSec = 30;
    restartLimitBurst = 5;

    # No auto-fetch: the IR is already on disk (the proven model).
    fetchModel.enable = false;

    # Metrics off per-node (cluster manifests land when we roll out).
    metrics.enable = false;
  };
}
