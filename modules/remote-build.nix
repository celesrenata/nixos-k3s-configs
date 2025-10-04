{ config, ... }:
{
  nix.distributedBuilds = true;
  nix.settings.system-features = [
    "kvm"
    "big-parallel"
    "nixos-test"
    "benchmark"
  ];
  
  # Configure gremlin-2, gremlin-3, and gremlin-4 as remote build servers
  # Intel Core Ultra 9 185H: 16 cores (6P+8E+2LP), 22 threads, 96GB RAM, RAID0 NVMe
  # Configured for 50% CPU utilization = ~11 threads
  nix.buildMachines = [
    {
      hostName = "gremlin-1";
      system = "x86_64-linux";
      protocol = "ssh";
      maxJobs = 11;  # 50% of 22 threads
      speedFactor = 3; # High performance: 96GB RAM + RAID0 NVMe + modern CPU
      supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
      mandatoryFeatures = [ ];
    }
    {
      hostName = "gremlin-2";
      system = "x86_64-linux";
      protocol = "ssh";
      maxJobs = 11;  # 50% of 22 threads
      speedFactor = 3; # High performance: 96GB RAM + RAID0 NVMe + modern CPU
      supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
      mandatoryFeatures = [ ];
    }
    {
      hostName = "gremlin-3";
      system = "x86_64-linux";
      protocol = "ssh";
      maxJobs = 11;  # 50% of 22 threads
      speedFactor = 3; # High performance: 96GB RAM + RAID0 NVMe + modern CPU
      supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
      mandatoryFeatures = [ ];
    }
    {
      hostName = "gremlin-4";
      system = "x86_64-linux";
      protocol = "ssh";
      maxJobs = 11;  # 50% of 22 threads
      speedFactor = 3; # High performance: 96GB RAM + RAID0 NVMe + modern CPU
      supportedFeatures = [ "nixos-test" "benchmark" "big-parallel" "kvm" ];
      mandatoryFeatures = [ ];
    }
  ];
}
