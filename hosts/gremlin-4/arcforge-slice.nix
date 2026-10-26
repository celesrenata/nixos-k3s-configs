{ config, lib, pkgs, ... }:

# ArcForge vertical slice on gremlin-1 (canary).
#
# This enables the host-native ArcForge embedding service on the PF render
# node, on a DEDICATED port (8100) so it coexists with the proven podman
# OVMS endpoint (port 8000) for A/B validation. It is the smallest stable
# slice: one service, one model, deterministic PF, numerically verified
# against the working endpoint.
#
# Rollout plan (one node at a time, each validated before the next):
#   gremlin-1 (this slice, port 8100)  -> validate
#   gremlin-2/3/4                     -> same module, same port
#   cutover                           -> OmniRoute switches 8000 -> 8100
#                                        (or this slice takes 8000 and the
#                                         podman service is retired)
#
# The slice reads the proven, world-readable OVMS-extracted IR from
# /var/lib/ovms-embeddings/models (read-only) rather than re-pulling, so it
# is byte-identical to the endpoint it must match.

let
  provenModelDir = "/var/lib/ovms-embeddings/models/OpenVINO/Qwen3-Embedding-0.6B-int8-ov";
in
{
  services.arcforge = {

    # Dedicated canary port so the proven podman OVMS (8000) stays live for
    # A/B comparison. After validation this becomes the production port.
    port = 8100;
    bindAddress = "0.0.0.0";

    # Deterministic PF selection (the physical-function render node on this
    # Meteor Lake node). Verified at activation against the PCI address.
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
      inferTimeoutSec = 60;
    };

    # Bounded GPU-fault recovery (one restart via watchdog; no reset storm).
    watchdogSec = 30;
    restartLimitBurst = 5;

    # No auto-fetch: the IR is already on disk (the proven model).
    fetchModel.enable = false;

    # Metrics off for the slice (cluster manifests land when we roll out).
    metrics.enable = false;
  };
}
