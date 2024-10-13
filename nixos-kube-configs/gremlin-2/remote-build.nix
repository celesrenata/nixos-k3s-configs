{ ... }:
{
  nix.distributedBuilds = true;
  nix.settings.system-features = [
    "kvm"
    "big-parallel"
    "nixos-test"
    "benchmark"
  ];
}
