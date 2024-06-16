{ ... }:
{
  nix.buildMachines = [
    {
      hostName = "gremlin-2";
      systems = ["x86_64-linux"];
      protocol = "ssh-ng";
      maxJobs = 4;
      speedFactor = 2;
      supportedFeatures = [ "nixos-test" ];
    }
    {
      hostName = "gremlin-3";
      systems = ["x86_64-linux"];
      protocol = "ssh-ng";
      maxJobs = 4;
      speedFactor = 2;
      supportedFeatures = [ "nixos-test" ];
    } 
 ];
  nix.distributedBuilds = true;
  nix.extraOptions = ''
    builders-use-substitutes = true
  '';
}
