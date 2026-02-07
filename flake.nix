{
  description = "gremlin-1 NixOS configuration with Intel hardware support";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    exo.url = "github:celesrenata/exo/ipex";
  };

  outputs = { self, nixpkgs, exo, ... }: {
    nixosConfigurations.gremlin-1 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hardware-configuration.nix
        exo.nixosModules.exo-intel
        {
          networking.hostName = "gremlin-1";
          
          # Boot loader configuration
          boot.loader.systemd-boot.enable = true;
          boot.loader.efi.canTouchEfiVariables = true;
          
          # System state version
          system.stateVersion = "24.11";
          
          # Enable Intel hardware support with tinygrad backend
          services.exo.intel = {
            enable = true;
            
            # Tinygrad backend configuration
            tinygrad = {
              enable = true;
              backend = "GPU";  # Use GPU acceleration
            };
            
            # Intel Arc iGPU configuration
            arc = {
              enable = true;
              runtime = "auto";  # Auto-detect Level Zero or OpenCL
            };
            
            # Intel NPU configuration (experimental)
            npu = {
              enable = true;
              servicePort = 52416;
            };
          };
          
          # Additional packages for testing and monitoring
          environment.systemPackages = with nixpkgs.legacyPackages.x86_64-linux; [
            intel-gpu-tools  # intel_gpu_top for GPU monitoring
            clinfo           # OpenCL device information
            pciutils         # lspci for hardware detection
            usbutils         # lsusb for USB devices
          ];
          
          # Ensure graphics support is enabled
          hardware.graphics = {
            enable = true;
            enable32Bit = false;  # Not needed for inference
          };
        }
      ];
    };
  };
}
