{
  description = "NixOS configuration flake for gremlin systems";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05";
    # Intel SR-IOV support
    #6.17 Known Good
    #i915-sriov.url = "github:bbaa-bbaa/i915-sriov-dkms/44e8daed8971bb5e66526667b2bbe56f46a0a62f";
    i915-sriov.url = "github:strongtz/i915-sriov-dkms/0d3c34fdf88bdeabd4c8d4927f5f02f4370f1508";
    i915-sriov.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixpkgs-stable, i915-sriov, ... }@inputs: 
  let
    # Helper function to create system configurations
    mkSystem = { hostname, pkgs ? nixpkgs, intel ? true, nvidia ? false, sriov ? true, resetMode ? false }: 
      pkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { 
          inherit inputs resetMode nixpkgs-stable; 
          systemHostname = hostname;
        };
        modules = [
          { nixpkgs.config.allowUnfree = true; }
          ./hosts/${hostname}/configuration.nix
          ./modules/common.nix
          ./modules/graphics.nix
          ./modules/networking.nix
          ./modules/virtualisation.nix
          ./modules/ups.nix 
          {
            gremlin.graphics = {
              intel.enable = intel;
              intel.sriov = intel && sriov;
              nvidia.enable = nvidia;
            };
          }
          # Conditionally include kubernetes and monitoring based on resetMode
        ] ++ (if resetMode then [] else [
          ./modules/kubernetes.nix
          ./modules/monitoring.nix
        ]);
      };
  in {
    nixosConfigurations = {
      # Normal configurations
      gremlin-1 = mkSystem { 
        hostname = "gremlin-1"; 
        intel = true;
        nvidia = true;
        sriov = true;
      };
      
      gremlin-2 = mkSystem { 
        hostname = "gremlin-2"; 
        intel = true;
        nvidia = false;
        sriov = true;
      };
      
      gremlin-3 = mkSystem { 
        hostname = "gremlin-3"; 
        intel = true;
        nvidia = false;
        sriov = true;
      };
      
      gremlin-4 = mkSystem { 
        hostname = "gremlin-4";
        intel = true;
        nvidia = false;
        sriov = true;
      };

      # Reset mode configurations (for cluster reset)
      gremlin-1-reset = mkSystem { 
        hostname = "gremlin-1"; 
        intel = true;
        nvidia = true;
        sriov = true;
        resetMode = true;
      };
      
      gremlin-2-reset = mkSystem { 
        hostname = "gremlin-2"; 
        intel = true;
        nvidia = false;
        sriov = true;
        resetMode = true;
      };
      
      gremlin-3-reset = mkSystem { 
        hostname = "gremlin-3"; 
        intel = true;
        nvidia = false;
        sriov = true;
        resetMode = true;
      };
      
      gremlin-4-reset = mkSystem { 
        hostname = "gremlin-4"; 
        intel = true;
        nvidia = false;
        sriov = true;
        resetMode = true;
      };

      # Future: gremlin-2 with NVIDIA (when ready)
      gremlin-2-nvidia = mkSystem { 
        hostname = "gremlin-2"; 
        intel = true;
        nvidia = true;
        sriov = true;
      };
    };
  };
}
