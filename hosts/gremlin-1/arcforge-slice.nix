{ config, lib, pkgs, ... }:

{
  imports = [
    ../../modules/services/arcforge/openvino.nix
    ../../modules/services/arcforge/rerank.nix
  ];

  services.arcforge.enable = true;
  services.arcforge.port = 8100;
  services.arcforge.bindAddress = "0.0.0.0";

  services.arcforge.device.renderNode = "/dev/dri/renderD128";
  services.arcforge.device.pciAddress = "0000:00:02.0";

  services.arcforge.model.dir = "/var/lib/ovms-embeddings/models/OpenVINO/Qwen3-Embedding-0.6B-int8-ov";
  services.arcforge.model.xml = null;
  services.arcforge.model.tokenizer = null;
  services.arcforge.model.name = "qwen3-embedding-0.6b";
  services.arcforge.model.version = "qwen3-embedding-0.6b-int8";
  services.arcforge.model.dim = 1024;
  services.arcforge.model.maxLength = 4096;
  services.arcforge.model.normalize = "l2";
  services.arcforge.model.padId = 0;

  services.arcforge.inference.concurrency = 4;
  services.arcforge.inference.batchLimit = 32;
  services.arcforge.inference.inferTimeoutSec = 60;
  services.arcforge.inference.probeIntervalSec = 10;
  services.arcforge.inference.probeTimeoutSec = 5;
  services.arcforge.inference.cache = "/var/cache/arcforge";

  services.arcforge.metrics.enable = true;
  services.arcforge.metrics.scrapePath = "/metrics";

  services.arcforge.fetchModel.enable = false;
}
