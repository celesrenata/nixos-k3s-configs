self: super: {
  gcc15 = super.gcc15.overrideAttrs (oldAttrs: rec {
    version = "15.2.1";
    src = super.fetchurl {
      url = "mirror://gcc/releases/gcc-${version}/gcc-${version}.tar.xz";
      sha256 = "0000000000000000000000000000000000000000000000000000000000000000";  # Will need actual hash
    };
  });
}
