{ config, lib, pkgs, ... }:

let
  cfg = config.services.arcforge;
  # The OpenVINO GPU plugin needs the Intel OpenCL ICD loader pointed at the
  # Intel Compute Runtime; without it the runtime maps an invalid driver and
  # fails at buffer-map time (clEnqueueMapBuffer CL_INVALID_VALUE).
  icr = pkgs.intel-compute-runtime;
  icd = pkgs.writeText "arcforge-intel.icd" "${icr}/lib/intel-opencl/libigdrcl.so\n";
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
  appScript = pkgs.writeText "arcforge-service.py" (builtins.readFile ./service.py);

  modelXml = if cfg.model.xml == null then "${cfg.model.dir}/openvino_model.xml" else cfg.model.xml;
  tokenizer = if cfg.model.tokenizer == null then "${cfg.model.dir}/tokenizer.json" else cfg.model.tokenizer;
  modelRoot = cfg.model.dir;
  renderNode = cfg.device.renderNode;

  verifyScript = pkgs.writeShellScript "arcforge-verify" (builtins.readFile ./verify-pf.sh);
in
{
  # Dedicated system service account (no shell) owning model + caches.
  users.users.arcforge = {
    isSystemUser = true;
    group = "arcforge";
    description = "ArcForge host-native GPU inference";
    useDefaultShell = false;
  };
  users.groups.arcforge = { };

  # Model + compile-cache state (kept out of the store).
  systemd.tmpfiles.rules = [
    "d /var/lib/arcforge 0755 arcforge arcforge - -"
    "d /var/lib/arcforge/models 0755 arcforge arcforge - -"
    "d /var/lib/arcforge/compile-cache 0755 arcforge arcforge - -"
  ];

  # One-shot model fetch / validation. In the common case the IR + tokenizer
  # are already on disk (pulled by the existing OVMS flow or a one-time manual
  # step); the unit then just validates and succeeds. If `source` is set, it
  # invokes the download helper. Only created when fetch is explicitly enabled.
  systemd.services.arcforge-model-fetch = lib.mkIf cfg.fetchModel.enable {
    description = "Fetch / validate ArcForge model (one-time)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    path = with pkgs; [ curl jq git coreutils ];
    serviceConfig = {
      User = "arcforge";
      Group = "arcforge";
      Type = "oneshot";
      RemainAfterExit = true;
      # Idempotent validation: succeed if the model is already present.
      ExecStart = "${pkgs.writeShellScript "arcforge-model-check" ''
        set -euo pipefail
        XML="${modelXml}"
        TOK="${tokenizer}"
        SRC="${cfg.fetchModel.source}"
        if [ -f "$XML" ] && [ -f "$TOK" ]; then
          echo "ArcForge model present at $XML; OK."
          exit 0
        fi
        if [ -n "$SRC" ]; then
          echo "ArcForge: model missing; downloading from $SRC"
          # The source is an OVMS-extracted graph directory or a tarball.
          # For a plain IR directory the operator pre-populates $XML; this
          # branch supports a tarball placed at /var/lib/arcforge/models.
          if [ -f "$SRC" ]; then
            tar -C "${modelRoot}" -xf "$SRC"
          else
            echo "ArcForge: cannot fetch model from $SRC" >&2
            exit 1
          fi
        fi
        echo "ArcForge: model not present at $XML (no source configured)" >&2
        exit 1
      ''}";
    };
  };

  # The inference service. This is the host-native execution path:
  #  * systemd service, not a container, not a pod.
  #  * closed device policy + PF-only DeviceAllow => exactly one GPU device.
  #  * OCL_ICD_VENDORS pins the Intel ICD (load-bearing for the GPU plugin).
  #  * eager GPU compile at start => readiness reflects the device, not lazy.
  #  * watchdog => bounded recovery (one restart, no reset storm).
  systemd.services.arcforge-embeddings = {
    description = "ArcForge host-native OpenVINO GPU embeddings (PF ${renderNode})";
    after = lib.optional cfg.fetchModel.enable "arcforge-model-fetch.service" ++ [ "network.target" "arcforge-verify.service" ];
    requires = lib.optional cfg.fetchModel.enable "arcforge-model-fetch.service" ++ [ "arcforge-verify.service" ];

    # Bounded restart (systemd >= 230: StartLimit* live in [Unit]).
    unitConfig = {
      StartLimitIntervalSec = "${toString cfg.restartLimitIntervalSec}";
      StartLimitBurst = "${toString cfg.restartLimitBurst}";
    };

    serviceConfig = {
      User = "arcforge";
      Group = "arcforge";
      Type = "notify";
      NotifyAccess = "main";

      # Bounded GPU-fault recovery. The app pings the watchdog every 1s while
      # healthy; when the GPU-fault circuit opens it stops pinging and systemd
      # restarts the unit once after WatchdogSec. No userspace device reset.
      WatchdogSec = "${toString cfg.watchdogSec}";
      Restart = "on-failure";
      RestartSec = "5";
      TimeoutStopSec = "30";

      # Deterministic PF-only device access. Closed policy means the only
      # device the process can open is the PF render node, so the OpenCL
      # loader sees exactly one GPU device — never a VF.
      DevicePolicy = "closed";
      DeviceAllow = [ "${renderNode} rw" ];

      # Supplementary group for the render node (owned root:video, mode 660).
      SupplementaryGroups = [ "video" ];

      # Environment (systemd wants a list of "KEY=VALUE" strings).
      Environment = lib.mapAttrsToList (n: v: "${n}=${v}") {
        OCL_ICD_VENDORS = "${icd}";
        ARCFORGE_MODEL_DIR = modelRoot;
        ARCFORGE_MODEL_XML = modelXml;
        ARCFORGE_TOKENIZER = tokenizer;
        ARCFORGE_MODEL_NAME = cfg.model.name;
        ARCFORGE_MODEL_VERSION = cfg.model.version;
        ARCFORGE_EMBED_DIM = (toString cfg.model.dim);
        ARCFORGE_MAX_LENGTH = (toString cfg.model.maxLength);
        ARCFORGE_DEVICE = "GPU";
        ARCFORGE_CONCURRENCY = (toString cfg.inference.concurrency);
        ARCFORGE_BATCH_LIMIT = (toString cfg.inference.batchLimit);
        ARCFORGE_INFER_TIMEOUT_S = (toString cfg.inference.inferTimeoutSec);
        ARCFORGE_PORT = (toString cfg.port);
        ARCFORGE_HOST = cfg.bindAddress;
        ARCFORGE_NORMALIZE = cfg.model.normalize;
        ARCFORGE_PAD_ID = (toString cfg.model.padId);
      };

      # Resource ceilings. Rendered as systemd K=V lines; per-host overrides
      # come through cfg.rlimit (a plain attrset of K -> V).
      ResourceLimits = (lib.mapAttrsToList (n: v: "${n}=${v}")
        ({ MemoryMax = "16G"; } // cfg.rlimit));

      ExecStart = "${pythonEnv}/bin/python ${appScript}";
    };
  };

  # Activation guard: fail loudly if the render node no longer maps to the
  # expected PF PCI function (deterministic device selection).
  systemd.services.arcforge-verify = {
    description = "Verify ArcForge PF render node maps to expected PCI address";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    path = with pkgs; [ coreutils ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${verifyScript} ${renderNode} ${cfg.device.pciAddress}";
    };
  };
}
