{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    opencode
  ];
} 
