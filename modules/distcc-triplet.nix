{ config, pkgs, lib, ... }:

let
  gccWithTriplet = pkgs.runCommand "gcc-with-triplet" {} ''
    mkdir -p $out/bin
    ln -s ${pkgs.gcc}/bin/gcc $out/bin/gcc
    ln -s ${pkgs.gcc}/bin/g++ $out/bin/g++
    ln -s ${pkgs.gcc}/bin/gcc $out/bin/x86_64-pc-linux-gnu-gcc
    ln -s ${pkgs.gcc}/bin/g++ $out/bin/x86_64-pc-linux-gnu-g++
  '';
in
{
  systemd.services.distccd = {
    path = [ gccWithTriplet ];
    environment.PATH = lib.mkForce "${gccWithTriplet}/bin";
  };
}
