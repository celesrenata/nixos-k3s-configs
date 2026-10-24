{ config, lib, pkgs, ... }:

# ArcForge security hardening for the native GPU inference unit.
#
# Primary isolation is the unit's device policy (closed + PF-only DeviceAllow,
# set in openvino.nix) — that is what keeps a VF / SR-IOV function out of the
# host process's reach. This module adds the remaining filesystem, home, tmp,
# and capability containment without interfering with OpenVINO's /sys-based
# device discovery.

let
  cfg = config.services.arcforge;
in
lib.mkIf cfg.enable {
  systemd.services."arcforge-embeddings".serviceConfig = {
    # Filesystem: read-only everywhere except the service's own state (State
    # Directory) and private tmp. OpenVINO reads its libraries from /nix/store
    # and discovers the GPU via /sys — both remain readable.
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    # Must be able to bind the LAN port (k3s workloads reach it).
    PrivateNetwork = false;
    # Only allow IPv4/IPv6 TCP sockets (no raw, no unix-domain surprises).
    RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
    # Never gain privileges; drop all capabilities.
    NoNewPrivileges = true;
    CapabilityBoundingSet = [ ];
    AmbientCapabilities = [ ];
    # Deterministic environment hygiene.
    UnsetEnvironment = [ "LD_PRELOAD" ];
  };
}
