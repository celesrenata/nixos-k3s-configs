{ config, pkgs, lib, system, ... }:

# ArcForge audio vertical — host-native STT + TTS on the Arc nodes ("zoo").
#
# Plain systemd services, no GPU passthrough (CPU inference; the Arc iGPU PF
# stays free for the reranker/embedders). Fixed ports, already in the firewall:
#   :10300  arcforge-stt — faster-whisper (Systran/faster-whisper-large-v3)
#                          POST /v1/audio/transcriptions
#                          POST /v1/audio/translations
#   :10200  arcforge-tts — kokoro-onnx (Kokoro-82M)
#                          POST /v1/audio/speech
#
# Model artifacts are NOT in the nix store — they live under /var/lib/arcforge-audio
# and are fetched by the arcforge-audio-model-fetch one-shot (idempotent).
let
  inherit (pkgs) writeText writeShellScript bash python314;
  espeakNg = pkgs."espeak-ng";
  coreutils = pkgs.coreutils;

  # STT env — faster-whisper + API server deps.
  sttEnv = python314.withPackages (ps: [
    ps.faster-whisper
    ps.fastapi
    ps.uvicorn
    ps.numpy
    ps.soundfile
    ps.huggingface-hub
    ps."python-multipart"
  ]);

  # TTS base env — kokoro-onnx itself is pip-installed into a writable venv at
  # /var/lib/arcforge-audio/tts-venv by model-fetch (not packaged for this
  # nixpkgs pin). espeak-ng is a SYSTEM package (binary), not a Python one —
  # it is added to the service PATH, not to this env.
  ttsBaseEnv = python314.withPackages (ps: [
    ps.onnxruntime
    ps.numba
    ps.numpy
    ps.soundfile
    ps.huggingface-hub
    ps.pydantic
    ps.fastapi
    ps.uvicorn
  ]);

  sttApp = writeText "arcforge-stt-service.py" (builtins.readFile ./stt-service.py);
  ttsApp = writeText "arcforge-tts-service.py" (builtins.readFile ./tts-service.py);

  # The model-fetch script must be executable (systemd ExecStart runs it
  # directly) — writeText does not set the exec bit, so use writeShellScript.
  modelFetch = writeShellScript "arcforge-audio-model-fetch.sh" (builtins.readFile ./audio-model-fetch.sh);

  # TTS launcher: espeak-ng on PATH (kokoro-onnx shells out to `espeak` for
  # phonemization), then exec the service.
  ttsLauncher = writeShellScript "arcforge-tts-launch.sh" ''
    export PATH="${espeakNg}/bin:${coreutils}/bin:$PATH"
    exec "${ttsBaseEnv}/bin/python3" "${ttsApp}"
  '';
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
      unitConfig = {
        StartLimitIntervalSec = "600";
        StartLimitBurst = 5;
      };
      serviceConfig = {
        Type = "oneshot";
        User = "arcforge-audio";
        Group = "arcforge-audio";
        Environment = [
          "STT_ENV=${sttEnv}"
          "TTS_BASE_ENV=${ttsBaseEnv}"
          "MODEL_DIR=/var/lib/arcforge-audio/stt-models"
          "HF_HOME=/var/lib/arcforge-audio/hf-cache"
          # kokoro-onnx load-sanity shells out to `espeak` for phonemization.
          "PATH=${espeakNg}/bin:${coreutils}/bin"
        ];
        ExecStart = "${modelFetch}";
        RemainAfterExit = true;
      };
    };

    systemd.services.arcforge-stt = {
      description = "ArcForge host-native faster-whisper STT";
      after = [ "network.target" "arcforge-audio-model-fetch.service" ];
      requires = [ "arcforge-audio-model-fetch.service" ];
      wantedBy = [ "multi-user.target" ];
      unitConfig = {
        StartLimitIntervalSec = "300";
        StartLimitBurst = 3;
      };
      serviceConfig = {
        Type = "simple";
        User = "arcforge-audio";
        Group = "arcforge-audio";
        WorkingDirectory = "/var/lib/arcforge-audio";
        Environment = [
          "MODEL_DIR=/var/lib/arcforge-audio/stt-models"
          "HF_HOME=/var/lib/arcforge-audio/hf-cache"
        ];
        ExecStart = "${sttEnv}/bin/python3 ${sttApp}";
        Restart = "on-failure";
        RestartSec = 5;
        TasksMax = 512;
        LimitNOFILE = 65536;
      };
    };

    systemd.services.arcforge-tts = {
      description = "ArcForge host-native kokoro-onnx TTS";
      after = [ "network.target" "arcforge-audio-model-fetch.service" ];
      requires = [ "arcforge-audio-model-fetch.service" ];
      wantedBy = [ "multi-user.target" ];
      unitConfig = {
        StartLimitIntervalSec = "300";
        StartLimitBurst = 3;
      };
      serviceConfig = {
        Type = "simple";
        User = "arcforge-audio";
        Group = "arcforge-audio";
        WorkingDirectory = "/var/lib/arcforge-audio";
        Environment = [
          "KOKORO_HOME=/var/lib/arcforge-audio/tts-models"
          "HF_HOME=/var/lib/arcforge-audio/hf-cache"
        ];
        ExecStart = "${ttsLauncher}";
        Restart = "on-failure";
        RestartSec = 5;
        TasksMax = 256;
        LimitNOFILE = 65536;
      };
    };
  };
}
