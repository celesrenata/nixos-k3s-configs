# Pin the default k3s package to the 1.36 line from upstream nixpkgs.
#
# Upstream nixpkgs keeps `pkgs.k3s` on the 1.35 line and exposes 1.36 only as
# `pkgs.k3s_1_36`. This overlay makes the default `pkgs.k3s` resolve to the
# 1.36 release so the whole config (services.k3s.package + PATH refs in
# modules/kubernetes.nix) tracks 1.36.x without threading `_1_36` everywhere.
final: prev: {
  k3s = prev.k3s_1_36;
}
