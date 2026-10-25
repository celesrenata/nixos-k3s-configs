{ ... }:

# Qdrant 1.20 TurboQuant sidecar — host-scoped to gremlin-1 (10.1.1.12) only.
#
# The production Qdrant 1.15.5 (qdrant.nix) stays on 6333/6334 untouched.
# This sidecar serves 1.18+ features (TurboQuant quantization, lossy datatypes,
# per-search rescoring) on 6433/6434 with its own state directory
# (/var/lib/qdrant-turbo), used for the ArcForge §6 quantization comparison
# and any future experimental indexing work. It is opt-in: nothing changes
# until services.qdrant-turbo.enable is set.
{
  imports = [
    ../../modules/services/qdrant-turbo.nix
  ];

  services.qdrant-turbo.enable = true;
}
