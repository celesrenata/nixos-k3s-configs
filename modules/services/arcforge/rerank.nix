{ config, lib, pkgs, ... }:

let
  cfg = config.services.arcforge-rerank;
  # The OpenVINO GPU plugin needs the Intel OpenCL ICD loader pointed at the
  # Intel Compute Runtime (same ICD as the embedding service).
  icr = pkgs.intel-compute-runtime;
  icd = pkgs.writeText "arcforge-rerank-intel.icd" "${icr}/lib/intel-opencl/libigdrcl.so\n";
  pythonEnv = pkgs.python3.withPackages (ps: with ps; [
    openvino
    numpy
    tokenizers
    fastapi
    uvicorn
    ps."prometheus-client"
    aiohttp
    pydantic
  ]);
  appScript = pkgs.writeText "arcforge-rerank-service.py" (builtins.readFile ./rerank-service.py);
  modelRoot = cfg.model.dir;
  renderNode = cfg.device.renderNode;
in
{
  # Dedicated service account for the reranker (group already created by the
  # embedding service module; both share /var/lib/arcforge state).
  users.users.arcforge-rerank = {
    isSystemUser = true;
    group = "arcforge";
    description = "ArcForge host-native GPU reranker";
    useDefaultShell = false;
  };

  # Reranker IR + tokenizer state (kept out of the store).
  systemd.tmpfiles.rules = [
    "d /var/lib/arcforge 0755 arcforge arcforge - -"
    "d /var/lib/arcforge/reranker 0755 arcforge arcforge - -"
  ];

  systemd.services.arcforge-rerank = lib.mkIf cfg.enable {
    description = "ArcForge host-native OpenVINO Qwen3-Reranker";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    # Bounded restart (systemd >= 230: StartLimit* live in [Unit]).
    unitConfig = {
      StartLimitIntervalSec = "300";
      StartLimitBurst = "5";
    };

    serviceConfig = {
      # Notify + watchdog: the app sends READY=1 once the model is compiled and
      # then pings every second. When the GPU breaker opens it stops pinging, so
      # systemd restarts the unit instead of leaving it permanently /ready=503.
      Type = "notify";
      NotifyAccess = "main";
      WatchdogSec = "${toString cfg.watchdogSec}";
      TimeoutStartSec = "180";
      User = "arcforge-rerank";
      Group = "arcforge";
      KillMode = "mixed";
      KillSignal = "SIGTERM";
      TimeoutStopSec = "30";
      Restart = "on-failure";
      RestartSec = "5";

      # Writable GPU kernel blob cache, owned by arcforge-rerank (see
      # arcforge-rerank.inference.cache).
      CacheDirectory = lib.optional (cfg.inference.cache != null) cfg.inference.cache;

      #  * closed device policy + PF-only DeviceAllow => exactly one GPU device.
      DevicePolicy = "closed";
      DeviceAllow = [ "${renderNode} rw" ];
      SupplementaryGroups = [ "video" ];

      # Environment (systemd wants a list of "KEY=VALUE" strings).
      Environment = lib.mapAttrsToList (n: v: "${n}=${v}") {
        OCL_ICD_VENDORS = "${icd}";
        ARCFORGE_RERANK_MODEL_DIR = modelRoot;
        ARCFORGE_RERANK_MODEL_NAME = cfg.model.name;
        ARCFORGE_RERANK_MODEL_VERSION = cfg.model.version;
        ARCFORGE_RERANK_MAX_LENGTH = (toString cfg.model.maxLength);
        ARCFORGE_RERANK_PAD_ID = (toString cfg.model.padId);
        ARCFORGE_DEVICE = "GPU";
        ARCFORGE_RERANK_CONCURRENCY = (toString cfg.inference.concurrency);
        ARCFORGE_RERANK_BATCH_LIMIT = (toString cfg.inference.batchLimit);
        ARCFORGE_RERANK_INFER_TIMEOUT_S = (toString cfg.inference.inferTimeoutSec);
        ARCFORGE_PROBE_INTERVAL_S = (toString cfg.inference.probeIntervalSec);
        ARCFORGE_PROBE_TIMEOUT_S = (toString cfg.inference.probeTimeoutSec);
        ARCFORGE_CACHE_DIR =
          lib.optionalString (cfg.inference.cache != null) "/var/cache/${cfg.inference.cache}";
        ARCFORGE_RERANK_PORT = (toString cfg.port);
        ARCFORGE_RERANK_HOST = cfg.bindAddress;
      };

      ExecStart = "${pythonEnv}/bin/python ${appScript}";
      # per-host overrides come through cfg.rlimit (attrset of K -> V).
    } // ({ MemoryMax = "16G"; } // cfg.rlimit);
  };

  # Open the rerank port on the firewall (OmniRoute + k3s workloads reach
  # 10.1.1.N:8101). Mirrors the embedding service's firewall handling.
  networking.firewall.allowedTCPPorts =
    lib.mkIf cfg.enable [ cfg.port ];
}
