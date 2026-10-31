{ config, pkgs, lib, system, ... }:

# ArcForge audio vertical — host-native STT + TTS on the Arc nodes ("zoo").
let
  inherit (pkgs) writeText;

  # Pinned nixpkgs rev.
  nixpkgsPkgs = import (builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/da6dc0e7b26060f2f71ce3ef7088fb56ee44fa36.tar.gz") {};

  # STT env.
  sttEnv = nixpkgsPkgs.python314.withPackages (ps: [
    ps.faster-whisper ps.fastapi ps.uvicorn ps.numpy ps.soundfile ps.huggingface-hub
  ]);

  # TTS base env.
  ttsBaseEnv = nixpkgsPkgs.python314.withPackages (ps: [
    ps.onnxruntime ps.numba ps.numpy ps.soundfile ps.huggingface-hub ps.espeak-ng ps.fastapi ps.uvicorn
  ]);

  sttApp = writeText "arcforge-stt-service.py" (builtins.readFile ./stt-service.py);
  ttsApp = writeText "arcforge-tts-service.py" (builtins.readFile ./tts-service.py);
  modelFetch = writeText "arcforge-audio-model-fetch.sh" (builtins.readFile ./audio-model-fetch.sh);
in
{
  # Option declarations.
  options.services.arcforge-audio = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable ArcForge audio services (STT/TTS on CPU).";
    };
  };

  # Configuration.
  config = lib.mkIf config.services.arcforge-audio.enable {
    users.users.arcforge-audio = {
      isSystemUser = true;
      group = "arcforge-audio";
      description = "ArcForge host-native audio (STT/TTS)";
      useDefaultShell = false;
    };
    users.groups.arcforge-audio = { };

    systemd.tmpfiles.rules = [
      "d /var/lib/arcforge-audio 0755 arcforge-audio arcforge-audio - -"
      "d /var/lib/arcforge-audio/stt-models 0755 arcforge-audio arcforge-audio - -"
      "d /var/lib/arcforge-audio/tts-models 0755 arcforge-audio arcforge-audio - -"
      "d /var/lib/arcforge-audio/tts-venv 0755 arcforge-audio arcforge-audio - -"
    ];

    systemd.services.arcforge-audio-model-fetch = {
      description = "ArcForge audio model fetch (one-shot, idempotent)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      unitConfig = { StartLimitIntervalSec = "600"; StartLimitBurst = 5; };
      serviceConfig = {
        Type = "oneshot";
        User = "arcforge-audio";
        Group = "arcforge-audio";
        Environment = [ "STT_ENV=" "TTS_BASE_ENV=" "HF_HOME=/var/lib/arcforge-audio/hf-cache" ];
        ExecStart = modelFetch;
        RemainAfterExit = true;
      };
    };

    systemd.services.arcforge-stt = {
      description = "ArcForge host-native faster-whisper STT";
      after = [ "network.target" "arcforge-audio-model-fetch.service" ];
      requires = [ "arcforge-audio-model-fetch.service" ];
      wantedBy = [ "multi-user.target" ];
      unitConfig = { StartLimitIntervalSec = "300"; StartLimitBurst = 3; };
      serviceConfig = {
        Type = "simple";
        User = "arcforge-audio";
        Group = "arcforge-audio";
        WorkingDirectory = "/var/lib/arcforge-audio";
        Environment = "MODEL_DIR=/var/lib/arcforge-audio/stt-models";
        ExecStart = "/bin/python3 ";
        Restart = "on-failure"; RestartSec = 5;
        TasksMax = 512; LimitNOFILE = 65536;
      };
    };

    systemd.services.arcforge-tts = {
      description = "ArcForge host-native kokoro-onnx TTS";
      after = [ "network.target" "arcforge-audio-model-fetch.service" ];
      requires = [ "arcforge-audio-model-fetch.service" ];
      wantedBy = [ "multi-user.target" ];
      unitConfig = { StartLimitIntervalSec = "300"; StartLimitBurst = 3; };
      serviceConfig = {
        Type = "simple";
        User = "arcforge-audio";
        Group = "arcforge-audio";
        WorkingDirectory = "/var/lib/arcforge-audio";
        Environment = "KOKORO_HOME=/var/lib/arcforge-audio/tts-models";
        ExecStart = "/var/lib/arcforge-audio/tts-venv/bin/python ";
        Restart = "on-failure"; RestartSec = 5;
        TasksMax = 256; LimitNOFILE = 65536;
      };
    };
  };
}
