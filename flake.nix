{
  description = "NixOS configuration flake for gremlin systems";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";
    # exo.url = "github:celesrenata/exo/ipex";
    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = { self, nixpkgs, nixpkgs-stable, sops-nix, ... }@inputs: 
  let
    # Helper function to create system configurations
    mkSystem = { hostname, pkgs ? nixpkgs, intel ? true, nvidia ? false, sriov ? true, resetMode ? false, exoIntel ? false }: 
      pkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { 
          inherit inputs resetMode nixpkgs-stable; 
          systemHostname = hostname;
        };
        modules = [
          sops-nix.nixosModules.sops
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
          # Conditionally include kubernetes and monitoring based on resetMode
        ] ++ (if resetMode then [] else [
          ./modules/kubernetes.nix
          ./modules/monitoring.nix
        ]);
        # ]) ++ (if exoIntel then [
        # Add exo Intel hardware support
        #   exo.nixosModules.exo-intel
        #   {
        #     services.exo.intel = {
        #       enable = true;
        #       tinygrad = {
        #         enable = true;
        #         backend = "GPU";
        #       };
        #       arc = {
        #         enable = true;
        #         runtime = "auto";
        #       };
        #       npu = {
        #         enable = false;
        #         servicePort = 52416;
        #       };
        #     };
        #   }
        # ] else []);
      };
  in {
    nixosConfigurations = {
      # Normal configurations
      gremlin-1 = mkSystem { 
        hostname = "gremlin-1"; 
        intel = true;
        nvidia = true;
        sriov = true;
        # exoIntel = true;  # Enable exo Intel support
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
