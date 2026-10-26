{ config, pkgs, lib, ... }:

# arc-embed-ceiling-boost / FEAT-001 canary: host-native OVMS embeddings on the
# MASTER/PF Intel Arc device, bypassing the SR-IOV VF compute path that wedges
# (ccs0 "Unexpected memirq status 0x0" + GPU fence timeouts). This runs the same
# openvino/model_server image and the same qwen3-embedding-0.6b model as the
# in-cluster StatefulSet, but bound to the physical function render node
# /dev/dri/renderD128 (PCI 0000:00:02.0) instead of a carved-out VF.
#
# This does NOT change the SR-IOV configuration (modules/i915-sriov.nix, the VF
# split, max_vfs, force_probe, vfio rebind are all left untouched). It only ADDS
# a host service targeting the PF. gremlin-1 only.

let
  # Pinned to the exact digest the in-cluster StatefulSet uses.
  ovmsImage = "docker.io/openvino/model_server@sha256:e7a448ec4eb885cab232a5f5ff8b9f41fb3b6f69401633c2af83cac260c40e8e";
  modelDir = "/var/lib/ovms-embeddings/models";
  restPort = 8000;                 # free host port (verified)
  pfRenderNode = "/dev/dri/renderD128"; # PF (0000:00:02.0 / card1)
  modelName = "qwen3-embedding-0.6b";
  sourceModel = "OpenVINO/Qwen3-Embedding-0.6B-int8-ov";
  maxLength = "8192";              # ceiling goal; verified by post-fix sweep
in {
  systemd.tmpfiles.rules = [
    "d /var/lib/ovms-embeddings 0755 5000 5000 -"
    "d ${modelDir} 0755 5000 5000 -"
  ];

  # One-shot model pull (idempotent: skips if the graph already exists).
  systemd.services.ovms-embeddings-host-pull = {
    description = "Pull qwen3-embedding-0.6b model for host-native OVMS (PF)";
    after = [ "docker.service" "network-online.target" ];
    requires = [ "docker.service" ];
    wants = [ "network-online.target" ];
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
      ${pkgs.docker}/bin/docker pull ${ovmsImage}
      ${pkgs.docker}/bin/docker run --rm \
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

  # Host-native OVMS serving bound to the PF render node.
  systemd.services.ovms-embeddings-host = {
    description = "Host-native OVMS embeddings on the PF Intel Arc device (FEAT-001 canary)";
    wantedBy = [ "multi-user.target" ];
    after = [ "docker.service" "ovms-embeddings-host-pull.service" ];
    requires = [ "docker.service" "ovms-embeddings-host-pull.service" ];
    serviceConfig = {
      Restart = "always";
      RestartSec = 5;
      # Clean any stale container from a prior run before starting.
      ExecStartPre = "-${pkgs.docker}/bin/docker rm -f ovms-embeddings-host";
      ExecStart = ''
        ${pkgs.docker}/bin/docker run --rm --name ovms-embeddings-host \
          --user 5000:5000 \
          --device ${pfRenderNode}:${pfRenderNode} \
          --group-add 500 \
          --group-add 303 \
          -p ${toString restPort}:8000 \
          -v ${modelDir}:/models:ro \
          ${ovmsImage} \
          --rest_port=8000 \
          --model_name=${modelName} \
          --model_path=/models/${sourceModel}
      '';
      ExecStop = "${pkgs.docker}/bin/docker stop ovms-embeddings-host";
    };
  };

  # Allow the host OVMS REST port through the firewall (cluster + LAN reach).
  networking.firewall.allowedTCPPorts = [ restPort ];
}
