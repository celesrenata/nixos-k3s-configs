{ config, pkgs, lib, system, ... }:

# ArcForge audio vertical — host-native STT + TTS on the Arc nodes ("zoo").
#
# Mirrors the arcforge rerank/embeddings vertical: plain systemd services,
# no GPU passthrough (CPU inference; the Arc iGPU PF stays free for the
# reranker/embedders). Fixed ports, already in the firewall:
#   :10300  arcforge-stt — faster-whisper (Systran/faster-whisper-large-v3)
#                          POST /v1/audio/transcriptions
#                          POST /v1/audio/translations
#   :10200  arcforge-tts — kokoro-onnx (Kokoro-82M)
#                          POST /v1/audio/speech
#
# OmniRoute reaches them through the self-hosted provider_nodes path:
#   "arcforge-stt-<n>/whisper-large-v3" and "arcforge-tts-<n>/<voice>",
#   hosts allowlisted via OMNIROUTE_LOCAL_AUDIO_HOSTS (no credential needed).
#
# Model artifacts are NOT in the nix store — they live under /var/lib/arcforge-audio
# and are fetched by the arcforge-audio-model-fetch one-shot (idempotent).

let
  inherit (pkgs) writeText;

  # Pinned nixpkgs rev == the flake's `nixpkgs` input, so env builds are
  # reproducible across all 4 nodes (eval + build happen at nixos-rebuild time).
  nixpkgsPkgs = import (builtins.fetchTarball "https://github.com/NixOS/nixpkgs/archive/da6dc0e7b26060f2f71ce3ef7088fb56ee44fa36.tar.gz") {};

  # STT env — identical to the validated canary env (faster-whisper 1.2.1,
  # ctranslate2 4.8.3, av, soundfile, huggingface-hub + API server).
  sttEnv = nixpkgsPkgs.python314.withPackages (ps: [
    ps.faster-whisper
    ps.fastapi
    ps.uvicorn
    ps.numpy
    ps.soundfile
    ps.huggingface-hub
  ]);

  # TTS base env — the kokoro-onnx python package itself is pip-installed into
  # a writable venv at /var/lib/arcforge-audio/tts-venv by model-fetch
  # (kokoro-onnx is not packaged for this nixpkgs pin).
  ttsBaseEnv = nixpkgsPkgs.python314.withPackages (ps: [
    ps.onnxruntime
    ps.numba
    ps.numpy
    ps.soundfile
    ps.huggingface-hub
    ps.espeak-ng
    ps.fastapi
    ps.uvicorn
  ]);

  sttApp = writeText "arcforge-stt-service.py" (builtins.readFile ./stt-service.py);
  ttsApp = writeText "arcforge-tts-service.py" (builtins.readFile ./tts-service.py);
  modelFetch = writeText "arcforge-audio-model-fetch.sh" (builtins.readFile ./audio-model-fetch.sh);
in
{
  users.users.arcforge-audio = lib.mkIf config.services.arcforge-audio.enable {
    isSystemUser = true;
    group = "arcforge-audio";
    description = "ArcForge host-native audio (STT/TTS)";
    useDefaultShell = false;
  };

  systemd.tmpfiles.rules = lib.mkIf config.services.arcforge-audio.enable [
    "d /var/lib/arcforge-audio 0755 arcforge-audio arcforge-audio - -"
    "d /var/lib/arcforge-audio/stt-models 0755 arcforge-audio arcforge-audio - -"
    "d /var/lib/arcforge-audio/tts-models 0755 arcforge-audio arcforge-audio - -"
    "d /var/lib/arcforge-audio/tts-venv 0755 arcforge-audio arcforge-audio - -"
  ];

  # One-shot, idempotent model fetch. Passes the nix env store paths via env
  # (never interpolated into the script body).
  systemd.services.arcforge-audio-model-fetch = lib.mkIf config.services.arcforge-audio.enable {
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
      Environment = "STT_ENV=${sttEnv}";
      Environment = "TTS_BASE_ENV=${ttsBaseEnv}";
      Environment = "HF_HOME=/var/lib/arcforge-audio/hf-cache";
      ExecStart = "${modelFetch}";
      RemainAfterExit = true;
    };
  };

  systemd.services.arcforge-stt = lib.mkIf config.services.arcforge-audio.enable {
    description = "ArcForge host-native faster-whisper STT (OpenAI-compatible /v1/audio/*)";
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
      Environment = "MODEL_DIR=/var/lib/arcforge-audio/stt-models";
      ExecStart = "${sttEnv}/bin/python3 ${sttApp}";
      Restart = "on-failure";
      RestartSec = 5;
      TasksMax = 512;
      LimitNOFILE = 65536;
    };
  };

  systemd.services.arcforge-tts = lib.mkIf config.services.arcforge-audio.enable {
    description = "ArcForge host-native kokoro-onnx TTS (OpenAI-compatible /v1/audio/speech)";
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
      Environment = "KOKORO_HOME=/var/lib/arcforge-audio/tts-models";
      ExecStart = "/var/lib/arcforge-audio/tts-venv/bin/python ${ttsApp}";
      Restart = "on-failure";
      RestartSec = 5;
      TasksMax = 256;
      LimitNOFILE = 65536;
    };
  };
}
