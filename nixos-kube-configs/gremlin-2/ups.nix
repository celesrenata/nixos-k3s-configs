{
  power.ups = {
    enable = true;
    mode = "netclient";
    upsmon.monitor.apcsmx1500-a = {
      powerValue = 1;
      user = "nutmaster";
      system = "apcsmx1500-a@10.1.1.12:3493";
      passwordFile = "/etc/nixos/.config/PasswordFiles/apc.pass";
    };
  };
}
