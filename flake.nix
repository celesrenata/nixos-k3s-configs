{
  description = "NixOS configuration flake for gremlin systems";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";
    exo.url = "github:celesrenata/exo/tensor-parallelism";
    sops-nix.url = "github:Mic92/sops-nix";
    i915-sriov.url = "github:strongtz/i915-sriov-dkms/kernel-v7.0";
  };

  outputs = { self, nixpkgs, nixpkgs-stable, exo, sops-nix, i915-sriov, ... }@inputs: 
  let
    system = "x86_64-linux";

    mkSystem = { hostname, intel ? true, nvidia ? false, sriov ? true, resetMode ? false, exoDistributed ? false }: 
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { 
          inherit inputs resetMode nixpkgs-stable; 
          systemHostname = hostname;
        };
        modules = [
          sops-nix.nixosModules.sops
          { nixpkgs.config.allowUnfree = true; }
          { nixpkgs.overlays = [ (import ./overlays/lmstudio.nix) ]; }
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
        ]) ++ (if exoDistributed then [
          exo.nixosModules.exo-distributed
          ({ pkgs, lib, ... }: {
            services.exo.distributed = {
              enable = true;
              package = exo.packages.${system}.exo;
              masterAddr = "10.1.1.12";
              intelGpuPackages = [ exo.packages.${system}.intel-compute-runtime exo.packages.${system}.intel-compute-runtime-drivers exo.packages.${system}.level-zero exo.packages.${system}.intel-oneapi-runtime pkgs.unified-memory-framework ];
              peers = [ "/ip4/10.1.1.12/tcp/4001" "/ip4/10.1.1.13/tcp/4001" "/ip4/10.1.1.14/tcp/4001" "/ip4/10.1.1.15/tcp/4001" ];
            };
          })
        ] else []);
      };
  in {
    nixosConfigurations = {
      gremlin-1 = mkSystem { hostname = "gremlin-1"; intel = true; nvidia = true; sriov = true; exoDistributed = true; };
      gremlin-2 = mkSystem { hostname = "gremlin-2"; intel = true; nvidia = false; sriov = true; exoDistributed = true; };
      gremlin-3 = mkSystem { hostname = "gremlin-3"; intel = true; nvidia = false; sriov = true; exoDistributed = true; };
      gremlin-4 = mkSystem { hostname = "gremlin-4"; intel = true; nvidia = false; sriov = true; exoDistributed = true; };
      gremlin-1-reset = mkSystem { hostname = "gremlin-1"; intel = true; nvidia = true; sriov = true; resetMode = true; };
      gremlin-2-reset = mkSystem { hostname = "gremlin-2"; intel = true; nvidia = false; sriov = true; resetMode = true; };
      gremlin-3-reset = mkSystem { hostname = "gremlin-3"; intel = true; nvidia = false; sriov = true; resetMode = true; };
      gremlin-4-reset = mkSystem { hostname = "gremlin-4"; intel = true; nvidia = false; sriov = true; resetMode = true; };
      gremlin-2-nvidia = mkSystem { hostname = "gremlin-2"; intel = true; nvidia = true; sriov = true; };
    };
  };
}
