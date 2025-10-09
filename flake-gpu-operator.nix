{
  description = "NixOS configuration flake for gremlin systems";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05";
    # Intel SR-IOV support
    i915-sriov.url = "github:strongtz/i915-sriov-dkms";
  };

  outputs = { self, nixpkgs, nixpkgs-stable, i915-sriov, ... }@inputs: 
  let
    # Helper function to create system configurations with reset mode support
    mkSystem = { hostname, pkgs ? nixpkgs, hasNvidia ? false, useGpuOperator ? false, resetMode ? false }: 
      pkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { 
          inherit inputs resetMode hasNvidia useGpuOperator; 
          systemHostname = hostname;
        };
        modules = [
          ./hosts/${hostname}/configuration.nix
          ./modules/common.nix
          # Graphics modules - choose based on GPU Operator usage
          (if hasNvidia then 
            (if useGpuOperator then ./modules/graphics-nvidia-gpu-operator.nix else ./modules/graphics-nvidia.nix)
           else ./modules/graphics-intel.nix)
          ./modules/networking.nix
          ./modules/virtualisation.nix
          ./modules/ups.nix
          # Conditionally include kubernetes and monitoring based on resetMode
        ] ++ (if resetMode then [] else [
          (if useGpuOperator then ./modules/kubernetes-gpu-operator.nix else ./modules/kubernetes.nix)
          ./modules/monitoring.nix
        ]);
      };
  in {
    nixosConfigurations = {
      # GPU Operator configurations (recommended)
      gremlin-1-gpu-operator = mkSystem { 
        hostname = "gremlin-1"; 
        hasNvidia = true;
        useGpuOperator = true;
      };
      
      gremlin-2-gpu-operator = mkSystem { 
        hostname = "gremlin-2"; 
        hasNvidia = false;
        useGpuOperator = true;
      };
      
      gremlin-3-gpu-operator = mkSystem { 
        hostname = "gremlin-3"; 
        hasNvidia = false;
        useGpuOperator = true;
      };

      # Legacy configurations (current setup)
      gremlin-1 = mkSystem { 
        hostname = "gremlin-1"; 
        hasNvidia = true; 
      };
      
      gremlin-2 = mkSystem { 
        hostname = "gremlin-2"; 
        hasNvidia = false;
      };
      
      gremlin-3 = mkSystem { 
        hostname = "gremlin-3"; 
        hasNvidia = false; 
      };
      
      gremlin-4 = mkSystem { 
        hostname = "gremlin-4";
        hasNvidia = false; 
      };

      # Reset mode configurations
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

      gremlin-2-nvidia-gpu-operator = mkSystem { 
        hostname = "gremlin-2"; 
        hasNvidia = true;
        useGpuOperator = true;
      };
    };
  };
}
