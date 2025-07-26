final: prev:
let
  firmwareFiles = prev.fetchFromGitHub {
    owner = "intel-gpu";
    repo = "intel-gpu-firmware";
    rev = "47ccc64812b43ddb4893625999e4dd128e8b918f";
    sha256 = "sha256-6L+3nA2AJwPhFusoNAW5YoC1hOb3r+W2SGETf7NjFi4=";
  };
in
{
  linux-firmwareOverride = prev.linux-firmware.overrideAttrs (old: {
    installPhase = (old.installPhase or "") + ''
      mkdir -p $out/lib/firmware/i915
      cp ${firmwareFiles}/firmware/mtl_guc_70.6.4.bin $out/lib/firmware/i915/mtl_guc_70.6.4.bin
      cp ${firmwareFiles}/firmware/mtl_huc_8.4.3_gsc.bin $out/lib/firmware/i915/mtl_huc_8.4.3_gsc.bin
      cp ${firmwareFiles}/firmware/mtl_gsc_102.0.0.1511.bin $out/lib/firmware/i915/mtl_gsc_102.0.0.1511.bin
    '';
  });
}
