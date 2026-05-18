{ pkgs, ... }:

{
  services.hardware.bolt.enable = true;

  boot.kernelModules = [
    "thunderbolt"
    "thunderbolt_net"
    "typec_ucsi"
    "ucsi_acpi"
    "intel_pmc_mux"
    "typec_thunderbolt"
  ];
}
