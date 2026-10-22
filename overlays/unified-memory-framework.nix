final: prev:
{
  unified-memory-framework = prev.unified-memory-framework.overrideAttrs (old: {
    doCheck = false;
  });
}
