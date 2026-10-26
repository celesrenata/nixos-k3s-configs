{ config, pkgs, lib, ... }:

{
  boot.kernelParams = [
    "i915.request_timeout_ms=30000"
  ];
}
