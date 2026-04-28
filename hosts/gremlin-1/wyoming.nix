{ config, pkgs, lib, ... }:
{
  nixpkgs.config.cudaSupport = true;

  nixpkgs.overlays = [
    (final: prev: {
      python3Packages = prev.python3Packages.override {
        overrides = pyfinal: pyprev: {
          ctranslate2 = pyprev.ctranslate2.overrideAttrs (oldAttrs: {
            nativeBuildInputs = (oldAttrs.nativeBuildInputs or []) ++ [ prev.cudaPackages.cudatoolkit ];
            cmakeFlags = (oldAttrs.cmakeFlags or []) ++ [ "-DWITH_CUDA=ON" ];
          });
        };
      };
    })
  ];

  services.wyoming = {
    faster-whisper.servers."main" = {
      enable = true;
      device = "cuda";
      model = "Systran/faster-whisper-base.en";
      language = "en";
      beamSize = 5;
      uri = "tcp://0.0.0.0:10300";
    };
    piper.servers."en" = {
      enable = true;
      voice = "en_US-lessac-medium";
      uri = "tcp://0.0.0.0:10200";
    };
  };
}
