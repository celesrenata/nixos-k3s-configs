{ config, lib, pkgs, ... }:

let
  cfg = config.services.qdrant-turbo;

  # Qdrant v1.20.0 official prebuilt musl static release binary.
  #
  # Why a fetched release binary instead of the nixpkgs package:
  #   - nixpkgs-unstable qdrant (1.18.2) fails to build on this host: an
  #     AVX512-VNNI intrinsic (llvm.x86.avx512.vpdpbusd.512) does not exist
  #     for rustc 1.98 / the bundled LLVM. The stable channel's qdrant is
  #     1.15.5, which predates TurboQuant.
  #   - The 1.20.0 source build (--features gpu, needed for the §7 GPU HNSW
  #     experiment) hits the same LLVM/AVX512 blocker, so the release binary
  #     is the only viable source for 1.18+ features on this host.
  #   - The official gnu tarball is dynamically linked (needs glibc ld.so;
  #     fails with nixos-stub-ld on NixOS). The musl tarball is a static
  #     single binary that runs as-is — no runtime closure required.
  #
  # The archive is version-pinned by SHA-256 (GitHub release assets are
  # immutable per tag). fetchurl does not extract tarballs, and the official
  # musl tarball holds a single bare `qdrant` binary (no top-level dir), so
  # untar it directly in a trivial derivation instead of going through a
  # stdenv unpackPhase (which expects a directory layout).
  staticQdrantArchive = pkgs.fetchurl {
    url = "https://github.com/qdrant/qdrant/releases/download/v1.20.0/qdrant-x86_64-unknown-linux-musl.tar.gz";
    sha256 = "b03a64616a1f41ddab78b480a318466541765f19835318113b1821cbea8df52c";
  };
  staticQdrant = pkgs.runCommand "qdrant-1.20.0-static" {} ''
    tar xzf ${staticQdrantArchive}
    mkdir -p $out/bin
    install -m 0755 qdrant $out/bin/qdrant
  '';

  stateDir = "/var/lib/qdrant-turbo";

  # Qdrant's CLI only accepts a few flags (host/ports/storage paths live in
  # the config file), so ship a minimal config pointing at the StateDirectory.
  configYaml = pkgs.writeText "qdrant-turbo-config.yaml" ''
    cluster:
      enabled: false
    service:
      host: ${cfg.bindAddress}
      http_port: ${toString cfg.httpPort}
      grpc_port: ${toString cfg.grpcPort}
    storage:
      storage_path: ${stateDir}/storage
      snapshots_path: ${stateDir}/snapshots
    telemetry_disabled: true
  '';
in
{
  options.services.qdrant-turbo = {
    enable = lib.mkEnableOption
      "a sidecar Qdrant 1.20 (TurboQuant-capable) instance for benchmarking/experiments, alongside the production 1.15.5 instance";

    bindAddress = lib.mkOption {
      type = lib.types.str;
      default = "10.1.1.12";
      description = "Address to bind HTTP/gRPC to (this host's bond0).";
    };

    httpPort = lib.mkOption {
      type = lib.types.port;
      default = 6433;
      description = "HTTP/REST + web UI port.";
    };

    grpcPort = lib.mkOption {
      type = lib.types.port;
      default = 6434;
      description = "gRPC port.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = staticQdrant;
      description = ''
        Qdrant binary package. Defaults to the pinned v1.20.0 musl static
        release binary. Override to point at a locally built binary (e.g. a
        --features gpu source build for the §7 GPU HNSW experiment) without
        changing the service wiring.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    users.users.qdrant-turbo = {
      isSystemUser = true;
      group = "qdrant-turbo";
      description = "Qdrant TurboQuant sidecar service account";
    };
    users.groups.qdrant-turbo = { };

    # Dedicated state, kept separate from the production instance's
    # /var/lib/qdrant.
    systemd.tmpfiles.rules = [
      "d ${stateDir} 0750 qdrant-turbo qdrant-turbo - -"
      "d ${stateDir}/storage 0750 qdrant-turbo qdrant-turbo - -"
      "d ${stateDir}/snapshots 0750 qdrant-turbo qdrant-turbo - -"
    ];

    systemd.services.qdrant-turbo = {
      description = "Qdrant 1.20 TurboQuant sidecar (benchmark/experiment instance)";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      unitConfig = {
        StartLimitIntervalSec = "300";
        StartLimitBurst = "5";
      };
      serviceConfig = {
        Type = "simple";
        User = "qdrant-turbo";
        Group = "qdrant-turbo";
        ExecStart = "${cfg.package}/bin/qdrant --config-path ${configYaml}";
        Environment = [ "RUST_BACKTRACE=1" ];
        Restart = "on-failure";
        KillMode = "mixed";
      };
    };

    # Open the sidecar's HTTP port on this host only (same scoping as the
    # production qdrant.nix; the shared firewall module covers every gremlin).
    networking.firewall.allowedTCPPorts = [
      cfg.httpPort
    ];
  };
}
