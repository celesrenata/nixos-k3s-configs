{ config, pkgs, lib, ... }:

let
  gccWithTriplet = pkgs.runCommand "gcc-with-triplet" {} ''
    mkdir -p $out/bin
    ln -s ${pkgs.gcc15}/bin/gcc $out/bin/gcc
    ln -s ${pkgs.gcc15}/bin/g++ $out/bin/g++
    ln -s ${pkgs.gcc15}/bin/gcc $out/bin/x86_64-pc-linux-gnu-gcc
    ln -s ${pkgs.gcc15}/bin/g++ $out/bin/x86_64-pc-linux-gnu-g++
    ln -s ${pkgs.gcc15}/bin/gcc-ar $out/bin/gcc-ar
    ln -s ${pkgs.gcc15}/bin/gcc-nm $out/bin/gcc-nm
    ln -s ${pkgs.gcc15}/bin/gcc-ranlib $out/bin/gcc-ranlib
    ln -s ${pkgs.gcc15}/bin/gcc-ar $out/bin/x86_64-pc-linux-gnu-gcc-ar
    ln -s ${pkgs.gcc15}/bin/gcc-nm $out/bin/x86_64-pc-linux-gnu-gcc-nm
    ln -s ${pkgs.gcc15}/bin/gcc-ranlib $out/bin/x86_64-pc-linux-gnu-gcc-ranlib
  '';
in
{
  systemd.services.distccd = {
    path = [ gccWithTriplet pkgs.distcc ];
    serviceConfig = {
      ExecStart = lib.mkForce "${pkgs.distcc}/bin/distccd --no-detach --daemon --enable-tcp-insecure --port 3632 --log-level warning --stats --stats-port 3633 --zeroconf --allow 192.168.42.0/25 --allow 10.1.1.0/24 --allow 10.42.0.0/16";
      Environment = lib.mkForce "PATH=${gccWithTriplet}/bin";
    };
  };
}
