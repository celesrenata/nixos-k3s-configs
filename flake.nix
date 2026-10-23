{
  description = "NixOS configuration flake for gremlin systems";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";
    # Replacement for the exo distributed inference cluster (decommissioned
    # 2026-10-22): Granite 4.2 8B API service on gremlin-1.
    granite4.url = "github:celesrenata/granite-4-rtx-4070-ti-super?ref=dcb0bb616409f17496ed830a32dbdf84700481f6";
    sops-nix.url = "github:Mic92/sops-nix";
    i915-sriov.url = "github:strongtz/i915-sriov-dkms?ref=2026.09.16";
  };

  outputs = { self, nixpkgs, nixpkgs-stable, granite4, sops-nix, i915-sriov, ... }@inputs: 
  let
    system = "x86_64-linux";

    mkSystem = { hostname, intel ? true, nvidia ? false, sriov ? true, resetMode ? false, granite4Rtx ? false }: 
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { 
          inherit inputs resetMode nixpkgs-stable; 
          systemHostname = hostname;
        };
        modules = [
          sops-nix.nixosModules.sops
          { nixpkgs.config.allowUnfree = true; }
          { nixpkgs.overlays = [ (import ./overlays/lmstudio.nix) (import ./overlays/librosa.nix) (import ./overlays/k3s-1_36.nix) (import ./overlays/unified-memory-framework.nix) ]; }
          ./hosts/${hostname}/configuration.nix
          ./modules/common.nix
          ./modules/graphics.nix
          ./modules/networking.nix
          ./modules/virtualisation.nix
          ./modules/ups.nix 
          ./modules/sops.nix
          {
            gremlin.graphics = {
              intel.enable = intel;
              intel.sriov = intel && sriov;
              nvidia.enable = nvidia;
            };
          }
        ] ++ (if resetMode then [] else [
          ./modules/kubernetes.nix
          ./modules/monitoring.nix
        ]) ++ (if granite4Rtx then [
          # Granite 4.2 8B API scaffold replaces the old exo distributed
          # cluster + ada-inference llama.cpp server on this host.
          granite4.nixosModules.granite4Rtx
          ({ pkgs, lib, ... }: {
            services.granite4-rtx = {
              enable = true;
              package = granite4.packages.${system}.api;
              listenAddress = "127.0.0.1";
              listenPort = 2701;
            };
          })
        ] else []);
      };
  in {
    nixosConfigurations = {
      gremlin-1 = mkSystem { hostname = "gremlin-1"; intel = true; nvidia = true; sriov = true; granite4Rtx = true; };
      gremlin-2 = mkSystem { hostname = "gremlin-2"; intel = true; nvidia = false; sriov = true; };
      gremlin-3 = mkSystem { hostname = "gremlin-3"; intel = true; nvidia = false; sriov = true; };
      gremlin-4 = mkSystem { hostname = "gremlin-4"; intel = true; nvidia = false; sriov = true; };
      gremlin-1-reset = mkSystem { hostname = "gremlin-1"; intel = true; nvidia = true; sriov = true; resetMode = true; };
      gremlin-2-reset = mkSystem { hostname = "gremlin-2"; intel = true; nvidia = false; sriov = true; resetMode = true; };
      gremlin-3-reset = mkSystem { hostname = "gremlin-3"; intel = true; nvidia = false; sriov = true; resetMode = true; };
      gremlin-4-reset = mkSystem { hostname = "gremlin-4"; intel = true; nvidia = false; sriov = true; resetMode = true; };
      gremlin-2-nvidia = mkSystem { hostname = "gremlin-2"; intel = true; nvidia = true; sriov = true; };
    };
  };
}
