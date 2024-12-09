{ ... }:
{
  nix.distributedBuilds = true;
  nix.settings.system-features = [
    "kvm"
    "big-parallel"
    "i686-linux"
    "nixos-test"
    "benchmark"
  ];
}
