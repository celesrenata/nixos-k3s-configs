{ config, pkgs, lib, ... }:

# arc-embed-ceiling-boost / FEAT-001: host-native OVMS embeddings on the
# MASTER/PF Intel Arc device, on ALL gremlin i915 nodes. This replaces serving
# arc-embed through the SR-IOV VF compute path (which wedges: ccs0 "Unexpected
# memirq status 0x0" + GPU fence timeouts). Each node runs its own OVMS bound to
# its physical-function render node /dev/dri/renderD128 (PCI 0000:00:02.0),
# serving qwen3-embedding-0.6b on host port 8000. OmniRoute load-balances across
# all four host endpoints (10.1.1.12-15:8000).
#
# Guarded to Intel-GPU gremlin hosts. Does NOT change the SR-IOV config
# (modules/i915-sriov.nix untouched); it only ADDS a PF-targeted host service.
# Container runtime is podman (daemonless, uniform across nodes); image is the
# same digest the old in-cluster StatefulSet used. The PF device group GID is
# resolved at RUNTIME (it drifts across nodes: 26 on some, 500 on others, and a
# live GID is not changed by a rebuild), so the container is given the correct
# supplementary group to open /dev/dri/renderD128.

let
  enabled = config.gremlin.graphics.intel.enable or false;
  ovmsImage = "docker.io/openvino/model_server@sha256:e7a448ec4eb885cab232a5f5ff8b9f41fb3b6f69401633c2af83cac260c40e8e";
  modelDir = "/var/lib/ovms-embeddings/models";
  restPort = 8000;
  pfRenderNode = "/dev/dri/renderD128";
  modelName = "qwen3-embedding-0.6b";
  sourceModel = "OpenVINO/Qwen3-Embedding-0.6B-int8-ov";
  # Per-item token ceiling. FEAT-003: the user asked for 8192, but a post-fix token
  # sweep on this MTL Arc PF proved a near-8192-token single item does not return
  # within budget (>90s) and WEDGES the GPU (ccs0 fence-timeout). 8192 FAILED the
  # gate; the proven-stable operating ceiling is 4096, which is also the ENFORCED
  # OmniRoute guard (OMNIROUTE_EMBEDDING_SPLIT_MAX_ITEM_TOKENS=4096, overflow=auto:
  # long inputs auto-split to <=4096, over-cap single items get a clean HTTP 400).
  # Both layers carry the SAME number (4096). A larger window needs the GPU
  # driver/firmware follow-up (i915-sriov-dkms / GuC-HuC bump) + a source-side
  # concurrency cap. See .agents/tasks/arc-embed-ceiling-boost.
  maxLength = "4096";
in {
  config = lib.mkIf enabled {
    virtualisation.podman = {
      enable = true;
      dockerCompat = false;
    };

    systemd.tmpfiles.rules = [
      "d /var/lib/ovms-embeddings 0755 5000 5000 -"
      "d ${modelDir} 0755 5000 5000 -"
    ];

    systemd.services.ovms-embeddings-host-pull = {
      description = "Pull qwen3-embedding-0.6b model for host-native OVMS (PF)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      path = [ pkgs.podman ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -eu
        GRAPH="${modelDir}/${sourceModel}/graph.pbtxt"
        if [ -f "$GRAPH" ] && grep -q "max_length: ${maxLength}" "$GRAPH"; then
          echo "Model already present with max_length ${maxLength}; skipping pull."
          exit 0
        fi
        podman pull ${ovmsImage}
        podman run --rm \
          --user 5000:5000 \
          -v ${modelDir}:/models \
          ${ovmsImage} \
          --pull \
          --model_repository_path=/models \
          --source_model=${sourceModel} \
          --model_name=${modelName} \
          --task=embeddings \
          --pooling=LAST \
          --truncate=true \
          --max_length=${maxLength} \
          --target_device=GPU
      '';
    };

    systemd.services.ovms-embeddings-host = {
      description = "Host-native OVMS embeddings on the PF Intel Arc device (FEAT-001)";
      wantedBy = [ "multi-user.target" ];
      after = [ "ovms-embeddings-host-pull.service" "network-online.target" ];
      requires = [ "ovms-embeddings-host-pull.service" ];
      path = [ pkgs.podman ];
      serviceConfig = {
        Restart = "always";
        RestartSec = 5;
        ExecStartPre = "-${pkgs.podman}/bin/podman rm -f ovms-embeddings-host";
      };
      script = ''
        DEV_GID="$(${pkgs.coreutils}/bin/stat -c %g ${pfRenderNode})"
        echo "PF ${pfRenderNode} device GID resolved at runtime: $DEV_GID"
        exec ${pkgs.podman}/bin/podman run --rm --name ovms-embeddings-host \
          --user 5000:5000 \
          --device ${pfRenderNode}:${pfRenderNode} \
          --group-add "$DEV_GID" \
          -p ${toString restPort}:8000 \
          -v ${modelDir}:/models:ro \
          ${ovmsImage} \
          --rest_port=8000 \
          --model_name=${modelName} \
          --model_path=/models/${sourceModel}
      '';
    };

    networking.firewall.allowedTCPPorts = [ restPort ];
  };
}
