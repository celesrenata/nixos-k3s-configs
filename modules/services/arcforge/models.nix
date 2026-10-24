{ config, lib, pkgs, ... }:

# ArcForge model catalog.
#
# Declares the models ArcForge serves and, for each, the parameters the
# service module needs (dim, max_length, pooling, normalization). This keeps
# the "identical model versions, tokenizers, pooling, normalization, and
# output dimensions across replicas" requirement declarative and testable:
# every replica consumes the same catalog entry, so they are structurally
# identical.
#
# The primary embedding model is the same one the proven OVMS endpoints serve
# (OpenVINO/Qwen3-Embedding-0.6B-int8-ov, LAST pooling, L2 normalization,
# 1024 dims, 4096-token ceiling).

let
  cfg = config.services.arcforge;
in
{
  options.arcforge = {
    modelCatalog = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "ArcForge per-model source of truth (source, dim, pooling, normalization).";
    };
  };

  options.services.arcforge.models = lib.mkOption {
    type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
    description = "Additional ArcForge model instances (rerank, classifier, vision).";
    default = { };
  };

  config = lib.mkIf cfg.enable {
    # The proven embedding model, expressed as the default catalog entry so
    # the primary service and any future replica reference the same
    # parameters. (The primary instance itself is instantiated from
    # services.arcforge.model in default.nix; this entry is the documented
    # source of truth.)
    arcforge.modelCatalog = lib.mkDefault {
      "qwen3-embedding-0.6b" = {
        source = "OpenVINO/Qwen3-Embedding-0.6B-int8-ov";
        dim = 1024;
        pooling = "LAST";
        normalize = "l2";
        maxLength = 4096;
        dtype = "int8";
        kind = "embedding";
        api = "openai-compat";  # /v1/embeddings
      };
    };
  };
}
