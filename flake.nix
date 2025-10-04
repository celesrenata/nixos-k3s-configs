{
  description = "NixOS configuration flake for gremlin systems";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05";
    # Intel SR-IOV support
    i915-sriov.url = "github:bbaa-bbaa/i915-sriov-dkms";
    i915-sriov.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixpkgs-stable, i915-sriov, ... }@inputs: 
  let
    # Helper function to create system configurations with reset mode support
    mkSystem = { hostname, pkgs ? nixpkgs, hasNvidia ? false, resetMode ? false }: 
      pkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { 
          inherit inputs resetMode hasNvidia nixpkgs-stable; 
          systemHostname = hostname;
        };
        modules = [
          { nixpkgs.config.allowUnfree = true; }
          ./hosts/${hostname}/configuration.nix
          ./modules/common.nix
          # Graphics modules now handle SR-IOV conditionally based on hasNvidia
          (if hasNvidia then ./modules/graphics-nvidia.nix else ./modules/graphics-intel.nix)
          ./modules/networking.nix
          ./modules/virtualisation.nix
          ./modules/ups.nix
          # Conditionally include kubernetes and monitoring based on resetMode
        ] ++ (if resetMode then [] else [
          ./modules/kubernetes.nix
          ./modules/monitoring.nix
        ]) ++ (if hasNvidia then [] else [
          # Only add i915-sriov module for Intel-only systems
          ./modules/i915-sriov-simple-fix.nix
        ]);
      };
  in {
    nixosConfigurations = {
      # Normal configurations
      gremlin-1 = mkSystem { 
        hostname = "gremlin-1"; 
        hasNvidia = true; 
      };
      
      gremlin-2 = mkSystem { 
        hostname = "gremlin-2"; 
        hasNvidia = false; # Will be true when NVIDIA is added
      };
      
      gremlin-3 = mkSystem { 
        hostname = "gremlin-3"; 
        hasNvidia = false; 
      };
      
      gremlin-4 = mkSystem { 
        hostname = "gremlin-4";
        hasNvidia = false; 
      };

      # Reset mode configurations (for cluster reset)
      gremlin-1-reset = mkSystem { 
        hostname = "gremlin-1"; 
        hasNvidia = true; 
        resetMode = true;
      };
      
      gremlin-2-reset = mkSystem { 
        hostname = "gremlin-2"; 
        hasNvidia = false;
        resetMode = true;
      };
      
      gremlin-3-reset = mkSystem { 
        hostname = "gremlin-3"; 
        hasNvidia = false;
        resetMode = true;
      };
      
      gremlin-4-reset = mkSystem { 
        hostname = "gremlin-4"; 
        hasNvidia = false;
        resetMode = true;
      };

      # Future: gremlin-2 with NVIDIA (when ready)
      gremlin-2-nvidia = mkSystem { 
        hostname = "gremlin-2"; 
        hasNvidia = true; 
      };
    };
  };
}
