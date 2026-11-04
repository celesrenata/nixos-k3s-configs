{
  # Open the Granite 4.2 8B API port on the LAN (the shared
  # modules/networking.nix firewall applies to every gremlin, so it is
  # scoped here). The service itself is configured in the flake
  # (services.granite4-rtx, listenAddress 0.0.0.0).
  networking.firewall.allowedTCPPorts = [
    2701    # granite4-rtx chat-completions API (GPU engine, r8 EAGLE head)
  ];
}
