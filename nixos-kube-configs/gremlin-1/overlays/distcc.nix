final: prev:
let
  pname = "distcc";
  version = "2021-03-11";
  distcc = prev.stdenv.mkDerivation {
    inherit pname version;
    src = prev.fetchFromGitHub {
      owner = "distcc";
      repo = "distcc";
      rev = "de21b1a43737fbcf47967a706dab4c60521dbbb1";
      sha256 = "0zjba1090awxkmgifr9jnjkxf41zhzc4f6mrnbayn3v6s77ca9x4";
    };

    nativeBuildInputs = with prev; [
      pkg-config autoconf automake which
      (python3.withPackages (p: [ p.setuptools ]))
    ];
    buildInputs = with prev; [ popt avahi gtk3 procps libiberty_static ];
    preConfigure = with prev;
    ''
      export CPATH=$(ls -d ${gcc14.cc}/lib/gcc/*/${gcc14.cc.version}/plugin/include)

      configureFlagsArray=( CFLAGS="-O2 -fno-strict-aliasing"
                            CXXFLAGS="-O2 -fno-strict-aliasing"
          --mandir=$out/share/man
                            ${lib.optionalString (sysconfDir != "") "--sysconfdir=${sysconfDir}"}
                            ${lib.optionalString static "LDFLAGS=-static"}
                            ${lib.withFeature (static == true || popt == null) "included-popt"}
                            ${lib.withFeature (avahi != null) "avahi"}
                            ${lib.withFeature (gtk3 != null) "gtk"}
                            --without-gnome
                            --enable-rfc2553
                            --disable-Werror   # a must on gcc 4.6
                           )
      installFlags="sysconfdir=$out/etc";

      ./autogen.sh
    '';

    # The test suite fails because it uses hard-coded paths, i.e. /usr/bin/gcc.
    doCheck = false;

    passthru = with prev; {
      # A derivation that provides gcc and g++ commands, but that
      # will end up calling distcc for the given cacheDir
      #
      # extraConfig is meant to be sh lines exporting environment
      # variables like DISTCC_HOSTS, DISTCC_DIR, ...
      links = extraConfig: (runCommand "distcc-links" { passthru.gcc = gcc14.cc; }
        ''
          mkdir -p $out/bin
          if [ -x "${prev.gcc14.cc}/bin/gcc" ]; then
            cat > $out/bin/gcc << EOF
            #!${runtimeShell}
            ${extraConfig}
            exec ${distcc}/bin/distcc gcc "\$@"
          EOF
            chmod +x $out/bin/gcc
          fi
          if [ -x "${gcc14.cc}/bin/g++" ]; then
            cat > $out/bin/g++ << EOF
            #!${runtimeShell}
            ${extraConfig}
            exec ${distcc}/bin/distcc g++ "\$@"
          EOF
            chmod +x $out/bin/g++
          fi
        '');
    };

    meta = {
      description = "Fast, free distributed C/C++ compiler";
      homepage = "http://distcc.org";
      license = "GPL";

      platforms = prev.lib.platforms.linux;
      maintainers = with prev.lib.maintainers; [ anderspapitto ];
    };
  };
in
  distcc
