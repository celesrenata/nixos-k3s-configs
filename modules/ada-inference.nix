{ config, lib, pkgs, ... }:

let
  root = "/home/celes/ada";
  binary = "${root}/llama.cpp/build/bin/llama-server";
  model = "${root}/models/qwen35-9b/Qwen3.5-9B-Q5_K_M.gguf";
in {
  systemd.services.ada-inference = {
    description = "Qwen3.5-9B Q5 utility inference server";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    path = [ pkgs.coreutils ];
    environment.LD_LIBRARY_PATH = "/run/opengl-driver/lib";

    script = ''
      test -x ${binary}
      test -r ${model}
      exec ${binary} \
        --model ${model} \
        --alias qwen3.5-9b-utility \
        --ctx-size 262144 \
        --parallel 4 \
        --flash-attn on \
        --cache-type-k q8_0 \
        --cache-type-v q8_0 \
        --batch-size 1024 \
        --ubatch-size 1024 \
        --host 0.0.0.0 \
        --port 2701 \
        --log-verbosity 4 \
        --no-webui \
        -t 16 \
        -tb 22 \
        --chat-template-kwargs '{"enable_thinking":false}'
    '';

    serviceConfig = {
      Type = "simple";
      User = "celes";
      Group = "users";
      Restart = "on-failure";
      RestartSec = 10;
      LimitNOFILE = 65536;
      KillSignal = "SIGTERM";
      TimeoutStopSec = 30;
    };
  };
}
