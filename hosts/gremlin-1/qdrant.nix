{ config, pkgs, lib, nixpkgs-stable, ... }:
let
  # The unstable nixpkgs qdrant (1.18.2) fails to compile on this host due to an
  # AVX512-VNNI intrinsic signature mismatch in rustc 1.98 (llvm.x86.avx512.
  # vpdpbusd.512). The stable channel's qdrant (1.15.5) builds and is available
  # prebuilt in cache.nixos.org, so we source the package from nixpkgs-stable.
  # nixpkgs-stable is threaded into every module via the flake's specialArgs.
  stablePkgs = import nixpkgs-stable {
    inherit (pkgs) system;
    config.allowUnfree = true;
  };
in
{
  # Qdrant vector search engine — host-scoped to gremlin-1 (10.1.1.12) only.
  # This module is imported solely by hosts/gremlin-1/configuration.nix, so it
  # never lands on gremlin-2/3/4.
  services.qdrant = {
    enable = true;
    package = stablePkgs.qdrant;
    settings.service = {
      # Bind to this node's bond0 address so it is reachable on 10.1.1.12.
      host = "10.1.1.12";
      http_port = 6333;   # REST + web UI
      grpc_port = 6334;   # gRPC
    };
  };

  # Open the HTTP port only on this host (the shared modules/networking.nix
  # firewall applies to every gremlin, so we scope 6333 here instead).
  networking.firewall.allowedTCPPorts = [
    6333    # Qdrant HTTP/REST
  ];
}
