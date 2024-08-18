final: prev:
rec {
  intel-gfx-sriov-service = prev.stdenv.mkDerivation rec {
    pname = "intel-gfx-sriov-service";
    version = "1.0.1";

    src = prev.fetchFromGitHub {
      owner = "intel";
      repo = "kubevirt-gfx-sriov";
      rev = "3ccb108bd7e8c5a5a9c466ac3c8aab3696e2a8fe";
      hash = "sha256-qVR+uULP+iQtSE8QEDu65xei5vqDe5B7HlIy1PT5ytc=";
    };
    #buildInputs = [ prev.sed ];
    buildPhase = ''
      sed -i 's|modprobe|/run/current-system/sw/bin/modprobe|g' scripts/configvfs.sh
      chmod +x scripts/configvfs.sh
    '';
    installPhase = ''
      find scripts -type f | awk '{ print "install -m755 -D " $0 " $out/" $0 }' | bash
    '';
  };
}
