
let
  vid = "051D";
  pid = "0002";
  upsname = "apcsmx1500-a";
  pass-master = "masterMonitorPassword"; # master password for nut
  pass-local = "localMonitorPassword"; # slave/local password for nut
in
{
  # at some point something will make a /var/state/ups directory,
  # chown that to nut:
  # $ sudo chown nut:nut /var/state/ups
  power.ups = {
    enable = true;
    users.nutmaster = {
      upsmon = "primary";
      passwordFile = "/etc/nixos/.config/PasswordFiles/apc.pass";
    };
    mode = "netserver";
    schedulerRules = "/etc/nixos/.config/nut/upssched.conf";
    upsmon.monitor.apcsmx1500-a = {
      powerValue = 1;
      user = "nutmaster";
      passwordFile = "/etc/nixos/.config/PasswordFiles/apc.pass";
    };
    # debug by calling the driver:
    # $ sudo NUT_CONFPATH=/etc/nut/ usbhid-ups -u nut -D -a apcsmx1500-a
    ups.${upsname} = {
      # find your driver here:
      # https://networkupstools.org/docs/man/usbhid-ups.html
      driver = "usbhid-ups";
      shutdownOrder = 0;
      description = "APC SMX1500RM2UNC UPS";
      port = "auto";
      directives = [
        "vendorid = ${vid}"
        "productid = ${pid}"
        "ignorelb"
        "override.battery.charge.low = 50"
        "override.battery.runtime.low = 1200"
      ];
      # this option is not valid for usbhid-ups
      maxStartDelay = null;
    };
    maxStartDelay = 30;
  };

  users = {
    users.nut = {
      isSystemUser = true;
      group = "nut";
      # it does not seem to do anything with this directory
      # but something errored without it, so whatever
      home = "/var/lib/nut";
      createHome = true;
    };
    groups.nut = { };
  };

  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ATTRS{idVendor}=="${vid}", ATTRS{idProduct}=="${pid}", MODE="664", GROUP="nut", OWNER="nut"
  '';

  systemd.services.upsd.serviceConfig = {
    User = "root";
    Group = "nut";
  };
  power.ups.upsd.listen = [
    {
      address = "0.0.0.0";
      port = 3493;
    }
  ];
  systemd.services.upsdrv.serviceConfig = {
    User = "root";
    Group = "nut";
  };
}

