
{ config, lib, ... }:
let
  vid = "051D";
  pid = "0002";
  upsname = "apcsmx1500-a";
  pass-master = "masterMonitorPassword"; # master password for nut
  pass-local = "localMonitorPassword"; # slave/local password for nut
  
  # gremlin-1 has the physical UPS and acts as server
  # gremlin-2 and gremlin-3 are clients
  isUpsServer = (config.networking.hostName == "gremlin-1");
in
{
  # at some point something will make a /var/state/ups directory,
  # chown that to nut:
  # $ sudo chown nut:nut /var/state/ups
  power.ups = {
    enable = true;
    
    # Server configuration (gremlin-1 only)
    users = lib.mkIf isUpsServer {
      nutmaster = {
        upsmon = "primary";
        passwordFile = "/etc/nixos/.config/PasswordFiles/apc.pass";
      };
    };
    
    mode = if isUpsServer then "netserver" else "netclient";
    
    schedulerRules = lib.mkIf isUpsServer "/etc/nixos/.config/nut/upssched.conf";
    
    upsmon.monitor.apcsmx1500-a = {
      powerValue = 1;
      user = "nutmaster";
      passwordFile = "/etc/nixos/.config/PasswordFiles/apc.pass";
      # For clients, specify the remote system
      system = lib.mkIf (!isUpsServer) "apcsmx1500-a@10.1.1.12:3493";
    };
    
    # Physical UPS configuration (gremlin-1 only)
    # debug by calling the driver:
    # $ sudo NUT_CONFPATH=/etc/nut/ usbhid-ups -u nut -D -a apcsmx1500-a
    ups = lib.mkIf isUpsServer {
      ${upsname} = {
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
    };
    
    maxStartDelay = 30;
  };

  # User and group configuration (all nodes need this)
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

  # USB device rules (gremlin-1 only, since it has the physical UPS)
  services.udev.extraRules = lib.mkIf isUpsServer ''
    SUBSYSTEM=="usb", ATTRS{idVendor}=="${vid}", ATTRS{idProduct}=="${pid}", MODE="664", GROUP="nut", OWNER="nut"
  '';

  # Server-specific systemd service configuration (gremlin-1 only)
  systemd.services = lib.mkIf isUpsServer {
    upsd.serviceConfig = {
      User = "root";
      Group = "nut";
    };
    upsdrv.serviceConfig = {
      User = "root";
      Group = "nut";
    };
  };
  
  # Network listener configuration (gremlin-1 only)
  power.ups.upsd.listen = lib.mkIf isUpsServer [
    {
      address = "0.0.0.0";
      port = 3493;
    }
  ];
}

