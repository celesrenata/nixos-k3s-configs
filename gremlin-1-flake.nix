# This file demonstrates what should be in /etc/nixos/flake.nix on gremlin-1
# to support the Qwen3.8-27B inference stack optimized for RTX 4070 Ti SUPER

{
  description = "NixOS configuration for gremlin-1 (RTX 4070 Ti SUPER)";
  
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    nix-darwin = { 
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-hardware, ... }@inputs:
    let
      system = "x86_64-linux";
      hostname = "gremlin-1";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      # NixOS configuration for gremlin-1
      nixosConfigurations.gremlin-1 = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          # Hardware configuration for RTX 4070 Ti SUPER
          nixos-hardware.nixosModules.common-gpu-nvidia
          nixos-hardware.nixosModules.common-pc-usb
          
          # GPU acceleration settings for NVIDIA 
          { 
            hardware.opengl = {
              enable = true;
              driSupport = true;
              driSupport32Bit = true;
            };
            
            # NVIDIA Driver settings for Ada architecture (SM89) 
            hardware.nvidia = {
              open = false; # Use proprietary driver
              pm = "auto";  # Power management
              nvidiaSettings = true; # Enable nvidia-settings
            };
            
            # CUDA specific settings for our inference stack
            environment.systemPackages = with pkgs; [
              cudaPackages.cudatoolkit
              cudaPackages.libcublas
              cudaPackages.libcurand
              llama.cpp
            ];
          }
          
          # Custom Qwen3.8 inference configuration
          { 
            # Model storage
            environment.variables.QWEN_MODELS_PATH = "/var/lib/qwen-models";
            
            # Qwen3.8 optimization settings
            systemd.services.qwen38-inference = {
              description = "Qwen3.8-27B optimized inference service";
              after = [ "network.target" "nvidia-persistenced.service" ];
              wantedBy = [ "multi-user.target" ];
              
              serviceConfig = {
                Type = "simple";
                User = "inference";
                Group = "inference";
                ExecStart = "/run/current-system/sw/bin/llama-server";
                ExecStartPost = ''
                  sleep 5
                  # Validate service startup
                  curl -f http://localhost:8082/health
                '';
                Restart = "always";
                RestartSec = 10;
                
                # Resource limits for GPU
                LimitNOFILE = 65536;
                LimitMEMLOCK = "infinity";
                
                # GPU device access
                DeviceAllow = [ "/dev/nvidia* rwm" ];
                
                # Security settings
                CapabilityBoundingSet = "";
                AmbientCapabilities = "";
              };
              
              # Environment variables
              environmentVariables = {
                CUDA_VISIBLE_DEVICES = "0";
                CUDA_LAUNCH_BLOCKING = "0";
                LLAMA_CPP_THREADS = "16";
                LLAMA_CPP_PORT = "8082";
                LLAMA_CPP_MODEL_PATH = "/var/lib/qwen-models/Qwen3.8-27B-UD-IQ3_XXS.gguf";
                LLAMA_CPP_DRAFT_MODEL_PATH = "/var/lib/qwen-models/mtp-Qwen3.8-27B-Q4_0.gguf";
              };
            };
            
            # Service configuration with MTP parameters
            # Following the exact recipe from lishuyu.app for 84 tok/s performance
            environment.etc."qwen38-optimization.conf".text = ''
              # Qwen3.8-27B MTP configuration for RTX 4070 Ti SUPER
              MODEL_PATH=/var/lib/qwen-models/Qwen3.8-27B-UD-IQ3_XXS.gguf
              DRAFT_MODEL_PATH=/var/lib/qwen-models/mtp-Qwen3.8-27B-Q4_0.gguf
              SPEC_TYPE=draft-mtp
              SPEC_DRAFT_N=3
              SPEC_DRAFT_MIN_CONFIDENCE=0.5
              CACHE_K_TYPE=q8_0
              CACHE_V_TYPE=q8_0
              BATCH_SIZE=512
              CONTEXT_CHECKPOINTS=1
              NO_KV_OFFLOAD=true
              FLASH_ATTN=true
            '';
          }
          
          # Standard NixOS modules 
          ./configuration.nix
        ];
      };
    };
}