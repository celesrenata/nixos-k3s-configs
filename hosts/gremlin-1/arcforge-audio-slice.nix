{ config, lib, pkgs, ... }:

{
  imports = [ ../../modules/services/arcforge-audio ];

  services.arcforge-audio.enable = true;
}
