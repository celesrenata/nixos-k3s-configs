final: prev:
let
  firmwareFile = prev.fetchurl {
    url = "https://cgit.freedesktop.org/drm/drm-firmware/plain/i915/mtl_guc_70.6.4.bin?h=mtl_guc_70.6.4&id=6e1a2bb8c76dd0189f26c710f7b341c0d724d948";
    hash = "sha256-Uqsujg/vuZ5fMYhKoFUqSk7hSDQl1YzVQs9CDG80yBg=";
  };
in
{
  linux-firmwareOverride = prev.linux-firmware.overrideAttrs (old: {
    installPhase = (old.installPhase or "") + ''
      mkdir -p $out/lib/firmware/i915
      cp ${firmwareFile} $out/lib/firmware/i915/mtl_guc_70.6.4.bin
    '';
  });
}
