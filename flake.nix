{
  description = "NixOS configuration flake for gremlin systems";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";
    exo.url = "github:celesrenata/exo";
  };

  outputs = { self, exo, nixpkgs, nixpkgs-stable, ... }@inputs: 
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
            boot.kernelParams = [ "intel_pstate=disable" ];
            powerManagement.cpuFreqGovernor = pkgs.lib.mkForce "userspace";
            systemd.services.disable-turbo = {
              description = "Disable CPU Turbo Boost";
              wantedBy = [ "multi-user.target" ];
              script = "echo 0 > /sys/devices/system/cpu/cpufreq/boost";
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
              };
            };
          }
          # External Modules
          exo.nixosModules.default
          # Intel hardware acceleration for exo
          exo.nixosModules.exo-intel
          {
            # Enable Intel Arc iGPU support for exo
            services.exo.intel = {
              enable = true;
              arc = {
                enable = true;
                runtime = "auto";  # Auto-select between Level Zero and OpenCL
              };
              # NPU support is experimental, enable if needed
              npu.enable = false;
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
