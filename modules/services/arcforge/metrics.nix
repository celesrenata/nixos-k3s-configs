{ config, lib, pkgs, ... }:

# ArcForge metrics wiring.
#
# The host service already exposes a Prometheus endpoint at /metrics (see
# service.py). This module:
#   * declares the scrape contract (port + path) and firewall,
#   * on the cluster-init node, applies (idempotently) the cluster-side
#     manifests: a static scrape-job ConfigMap wired into the existing
#     prometheus-kube-prometheus stack, and a Grafana dashboard.
#
# The cluster monitoring stack is managed out-of-band, so we drop ready-to-use
# manifests into it without touching the operator or existing dashboards.

let
  cfg = config.services.arcforge;

  # Host LAN IPs of the nodes that run the ArcForge service.
  nodeIps = {
    gremlin-1 = "10.1.1.12";
    gremlin-2 = "10.1.1.13";
    gremlin-3 = "10.1.1.14";
    gremlin-4 = "10.1.1.15";
  };
  scrapePort = cfg.port;

  # One static scrape job per node. Nodes without the service will show as
  # down in Grafana until the slice is rolled out to them (expected).
  scrapeJobs = lib.concatMapStringsSep "\n" (host: ''
    - job_name: arcforge-${host}
      metrics_path: /metrics
      static_configs:
        - targets: [ "${nodeIps.${host}}:${toString scrapePort}" ]
      relabel_configs:
        - target_label: instance
          replacement: ${host}
  '') (builtins.attrNames nodeIps);

  scrapeYaml = builtins.toFile "arcforge-scrape.yaml" ''
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: arcforge-scrape-config
      namespace: prometheus-service
    data:
      additional-scrape-configs.yaml: |
        ${scrapeJobs}
  '';

  dashYaml = builtins.toFile "arcforge-dashboard.yaml" ''
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: arcforge-dashboard
      namespace: prometheus-grafana
      labels:
        grafana_dashboard: "1"
    data:
      arcforge.json: |
        ${lib.generators.toPretty {
          indentLevel = 1;
          lists = indent: json: builtins.concatMapStringsSep "\n" (obj: "    ${lib.toPretty (indent+1) obj}") json;
        } {
          title = "ArcForge - Host-Native Intel Arc Inference";
          uid = "arcforge";
          panels = [
            {
              title = "Embeddings / s (per node)";
              type = "timeseries";
              targets = [ { expr = "sum by (instance) (rate(arcforge_embedding_requests_total{status=\"ok\"}[5m]) * 30)"; legendFormat = "{{instance}}"; } ];
            }
            {
              title = "Inference latency p50/p95/p99 (s)";
              type = "timeseries";
              targets = [
                { expr = "histogram_quantile(0.50, sum by (le, instance) (rate(arcforge_embedding_inference_seconds_bucket[5m])))"; legendFormat = "p50 {{instance}}"; }
                { expr = "histogram_quantile(0.95, sum by (le, instance) (rate(arcforge_embedding_inference_seconds_bucket[5m])))"; legendFormat = "p95 {{instance}}"; }
                { expr = "histogram_quantile(0.99, sum by (le, instance) (rate(arcforge_embedding_inference_seconds_bucket[5m])))"; legendFormat = "p99 {{instance}}"; }
              ];
            }
            {
              title = "GPU-fault circuit open (1 = wedged)";
              type = "stat";
              targets = [ { expr = "arcforge_device_wedged"; legendFormat = "{{instance}}"; } ];
            }
            {
              title = "Concurrent inferences + queue depth";
              type = "timeseries";
              targets = [
                { expr = "arcforge_embedding_active_inferences"; legendFormat = "active {{instance}}"; }
                { expr = "arcforge_embedding_queue_depth"; legendFormat = "queue {{instance}}"; }
              ];
            }
          ];
        }}
  '';

  applyScript = pkgs.writeShellScript "arcforge-apply-monitoring" ''
    set -euo pipefail
    export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
    ${pkgs.k3s}/bin/kubectl apply -f ${scrapeYaml}
    ${pkgs.k3s}/bin/kubectl apply -f ${dashYaml}
    echo "ArcForge monitoring manifests applied."
  '';
in
lib.mkIf (cfg.enable && cfg.metrics.enable) {
  networking.firewall.allowedTCPPorts = [ cfg.port ];

  # Apply cluster manifests once on the control plane (idempotent; safe to
  # re-run on every boot — `kubectl apply` is a no-op when unchanged).
  systemd.services.arcforge-monitoring = lib.mkIf (config.networking.hostName == "gremlin-1") {
    description = "Apply ArcForge Prometheus/Grafana manifests to k3s";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "k3s.service" ];
    requires = [ "k3s.service" ];
    path = with pkgs; [ k3s ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = false;
      # Retry until k3s is actually serving the API (post-upgrade windows).
      ExecStart = applyScript;
      TimeoutStartSec = "300";
    };
  };
}
