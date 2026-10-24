{ config, lib, pkgs, ... }:

# ArcForge — host-native Intel Arc (iGPU PF) inference on NixOS.
#
# Serves embedding inference as a native systemd service that opens ONLY the
# physical-function render node (a closed device policy), so the OpenCL loader
# sees exactly one GPU device. No SR-IOV, no Kubernetes, no container GPU
# passthrough, no silent CPU fallback.
#
# Option tree (leaf defaults apply per-leaf, so setting one sub-option never
# drops its siblings):
#   services.arcforge.enable
#   services.arcforge.port
#   services.arcforge.bindAddress
#   services.arcforge.device.{renderNode,pciAddress}
#   services.arcforge.model.{dir,xml,tokenizer,name,version,dim,maxLength,normalize,padId}
#   services.arcforge.inference.{concurrency,batchLimit,inferTimeoutSec}
#   services.arcforge.watchdogSec
#   services.arcforge.restartLimitBurst
#   services.arcforge.restartLimitIntervalSec
#   services.arcforge.rlimit
#   services.arcforge.fetchModel.{enable,source}
#   services.arcforge.metrics.{enable,scrapePath}

{
  imports = [
    ./openvino.nix
    ./security.nix
    ./metrics.nix
    ./models.nix
  ];

  options.services.arcforge.enable =
    lib.mkEnableOption "ArcForge host-native OpenVINO GPU inference service";

  options.services.arcforge.port = lib.mkOption {
    type = lib.types.port;
    default = 8100;
  };
  options.services.arcforge.bindAddress = lib.mkOption {
    type = lib.types.str;
    default = "0.0.0.0";
  };

  options.services.arcforge.device.renderNode = lib.mkOption {
    type = lib.types.path;
    default = "/dev/dri/renderD128";
    description = "PF render node the service is allowed to open.";
  };
  options.services.arcforge.device.pciAddress = lib.mkOption {
    type = lib.types.str;
    default = "0000:00:02.0";
    description = "Expected PF PCI address (verified at activation).";
  };

  options.services.arcforge.model.dir = lib.mkOption {
    type = lib.types.path;
    default = "/var/lib/arcforge/models";
    description = "On-disk IR + tokenizer directory.";
  };
  options.services.arcforge.model.xml = lib.mkOption {
    type = lib.types.path;
    default = "";
    description = "IR .xml path; defaults to <dir>/openvino_model.xml when empty.";
  };
  options.services.arcforge.model.tokenizer = lib.mkOption {
    type = lib.types.path;
    default = "";
    description = "Tokenizer path; defaults to <dir>/tokenizer.json when empty.";
  };
  options.services.arcforge.model.name = lib.mkOption {
    type = lib.types.str;
    default = "qwen3-embedding-0.6b";
    description = "Model id served via /v1/models and /v1/embeddings.";
  };
  options.services.arcforge.model.version = lib.mkOption {
    type = lib.types.str;
    default = "qwen3-embedding-0.6b-int8";
    description = "Model version metadata (replicas must be identical).";
  };
  options.services.arcforge.model.dim = lib.mkOption {
    type = lib.types.int;
    default = 1024;
    description = "Embedding output dimension.";
  };
  options.services.arcforge.model.maxLength = lib.mkOption {
    type = lib.types.int;
    default = 4096;
    description = "Per-item token ceiling (matches the proven OVMS guard).";
  };
  options.services.arcforge.model.normalize = lib.mkOption {
    type = lib.types.enum [ "l2" "none" ];
    default = "l2";
    description = "Output normalization (must match the proven endpoint).";
  };
  options.services.arcforge.model.padId = lib.mkOption {
    type = lib.types.int;
    default = 0;
    description = "Pad token id.";
  };

  options.services.arcforge.inference.concurrency = lib.mkOption {
    type = lib.types.ints.positive;
    default = 4;
    description = "Parallel GPU worker streams (one per open InferRequest).";
  };
  options.services.arcforge.inference.batchLimit = lib.mkOption {
    type = lib.types.ints.positive;
    default = 32;
    description = "Max items per /v1/embeddings request.";
  };
  options.services.arcforge.inference.inferTimeoutSec = lib.mkOption {
    type = lib.types.ints.positive;
    default = 120;
    description = "Circuit-breaker timeout for a single inference.";
  };

  options.services.arcforge.watchdogSec = lib.mkOption {
    type = lib.types.ints.positive;
    default = 30;
    description = "systemd WatchdogSec; the service pings every 1s.";
  };
  options.services.arcforge.restartLimitBurst = lib.mkOption {
    type = lib.types.ints.positive;
    default = 5;
    description = "Max rapid restarts before the unit enters failed state.";
  };
  options.services.arcforge.restartLimitIntervalSec = lib.mkOption {
    type = lib.types.ints.positive;
    default = 60;
  };
  options.services.arcforge.rlimit = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    default = { };
    description = "Additional systemd ResourceLimits (e.g. MemoryMax).";
  };

  options.services.arcforge.fetchModel.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };
  options.services.arcforge.fetchModel.source = lib.mkOption {
    type = lib.types.str;
    default = "";
    description = "Model source (path to a tarball or the model dir to validate).";
  };

  options.services.arcforge.metrics.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Wire ArcForge metrics into the cluster monitoring stack.";
  };
  options.services.arcforge.metrics.scrapePath = lib.mkOption {
    type = lib.types.str;
    default = "/metrics";
  };

  config = lib.mkIf config.services.arcforge.enable {
    # Open the API port on the host firewall so k3s workloads (and OmniRoute)
    # can reach the endpoint over the LAN.
    networking.firewall.allowedTCPPorts = [ config.services.arcforge.port ];
  };
}
