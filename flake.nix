{
  description = "NixOS configuration flake for gremlin systems";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.11";
    exo.url = "github:celesrenata/exo/xpu";
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
          ({ pkgs, ... }: {
            # Packages needed for exo to run from source
            environment.systemPackages = with pkgs; [ uv git nodejs ];
            programs.nix-ld.enable = true;

            systemd.services.exo = {
              description = "exo Distributed AI Inference Service";
              wantedBy = [ "multi-user.target" ];
              after = [ "network-online.target" ];
              wants = [ "network-online.target" ];

              path = with pkgs; [ uv python312 git nodejs bash coreutils gcc gnumake pkg-config openssl ];

              environment = {
                MASTER_ADDR = "10.1.1.12";
                MASTER_PORT = "29500";
                LD_LIBRARY_PATH = builtins.concatStringsSep ":" [
                  "${pkgs.stdenv.cc.cc.lib}/lib"
                  "/run/opengl-driver/lib"
                  # Intel GPU runtime for torch.xpu (Level Zero + compute runtime)
                  "${pkgs.intel-compute-runtime.drivers}/lib"
                  "${pkgs.level-zero}/lib"
                  # OpenCL runtime — oneDNN needs this for SDPA and other kernels
                  "${pkgs.intel-compute-runtime}/lib/intel-opencl"
                ];
                UV_PYTHON_PREFERENCE = "only-system";
                UV_PYTHON = "python3.12";
                HOME = "/root";
                # OpenCL ICD vendor path for oneDNN
                OCL_ICD_VENDORS = "${pkgs.intel-compute-runtime}/etc/OpenCL/vendors";
              };

              serviceConfig = {
                Type = "simple";
                WorkingDirectory = "/opt/exo";
                ExecStartPre = "${pkgs.writeShellScript "exo-prepare" ''
                  set -euo pipefail
                  EXO_DIR=/opt/exo
                  if [ ! -d "$EXO_DIR/.git" ]; then
                    ${pkgs.git}/bin/git clone --branch xpu https://github.com/celesrenata/exo.git "$EXO_DIR"
                  else
                    cd "$EXO_DIR"
                    ${pkgs.git}/bin/git fetch origin xpu
                    ${pkgs.git}/bin/git reset --hard origin/xpu
                  fi
                ''}";
                ExecStart = "${pkgs.uv}/bin/uv run exo -vv";
                Restart = "on-failure";
                RestartSec = "10s";
                User = "root";
                Group = "root";
                StandardOutput = "journal";
                StandardError = "journal";
                SyslogIdentifier = "exo";
              };
            };

            networking.firewall.allowedTCPPortRanges = [
              { from = 49152; to = 65535; }
            ];
            networking.firewall.allowedTCPPorts = [ 29500 52415 ];
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
