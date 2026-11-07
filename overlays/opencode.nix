# Bump opencode past the version pinned in the current nixpkgs.
#
# opencode has TWO fixed-output hashes that must track the release:
#   * `src`            — the GitHub tarball, resolved by the flake's
#                       fetchFromGitHub (prefer-remote-fetch). Note this is
#                       NOT necessarily the same as a plain `curl` of the
#                       same tag URL.
#   * `node_modules`   — the recursive `bun install` output; it changes
#                       whenever the source does.
#
# To update again, change `version` and recompute both hashes:
#   1. `src`            via nix's fetcher (not plain curl), e.g. build once with
#                       a placeholder hash and read the `got:` line, or
#                       nix-prefetch-url on the exact fetchFromGitHub URL.
#   2. `node_modules`   build the inner derivation with a placeholder outputHash
#                       and read the `got:` line.
# Then `nixos-rebuild`.
final: prev:
let
  version = "2.2.6";
in
{
  opencode = prev.opencode.overrideAttrs (old: {
    inherit version;

    src = old.src.overrideAttrs (srcOld: {
      hash = "sha256-6Of4/r4SKYtxMbHISu8/4yzSpCfHNGuTwfKdAKjNJnM=";
    });

    node_modules = old.node_modules.overrideAttrs (nmOld: {
      inherit version;
      src = final.opencode.src;
      outputHash = "sha256-UOF9owEBSuVKX/hBhef7Wr4ymlNgTL21BiVBr+9a8Zo=";
    });
  });
}
