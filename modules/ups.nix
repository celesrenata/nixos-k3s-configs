
{ config, lib, pkgs, ... }:
let
  vid = "051D";
  pid = "0002";
  upsname = "apcsmx1500-a";
  pass-master = "masterMonitorPassword"; # master password for nut
  pass-local = "localMonitorPassword"; # slave/local password for nut
  
  # gremlin-1 has the physical UPS and acts as server
  # gremlin-2 and gremlin-3 are clients
  isUpsServer = (config.networking.hostName == "gremlin-1");

  # upssched.conf content - shared by all nodes
  upsschedConf = pkgs.writeText "upssched.conf" ''
    CMDSCRIPT /etc/nut/upssched-cmd
    PIPEFN /var/state/ups/upssched.pipe
    LOCKFN /var/state/ups/upssched.lock

    # When on battery, wait 60 seconds before starting shutdown
    AT ONBATT * START-TIMER onbatt 60
    # If power returns, cancel the shutdown
    AT ONLINE * CANCEL-TIMER onbatt
    # On comms lost, wait 60 seconds (covers brief network blips)
    AT COMMBAD * START-TIMER commbad 60
    AT COMMOK * CANCEL-TIMER commbad
    # Low battery = shut down immediately (no delay, battery is critical)
    AT LOWBATT * EXECUTE lowbatt
    # FSD from server = shut down immediately
    AT FSD * EXECUTE fsd
  '';
in
{
  # Ensure /var/state/ups exists with correct ownership
  systemd.tmpfiles.rules = [
    "d /var/state/ups 0750 nut nut -"
  ];
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
    
    # Point all nodes to the same upssched config
    schedulerRules = "${upsschedConf}";
    
    upsmon.monitor.apcsmx1500-a = {
      powerValue = 1;
      user = "nutmaster";
      passwordFile = "/etc/nixos/.config/PasswordFiles/apc.pass";
      type = if isUpsServer then "primary" else "secondary";
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

  # upssched command script - handles timer expiry events
  environment.etc."nut/upssched-cmd" = {
    text = ''
      #!/bin/sh
      case $1 in
        onbatt)
          logger -t upssched-cmd "UPS on battery for 60 seconds, initiating shutdown"
          /run/current-system/sw/bin/upsmon -c fsd
          ;;
        commbad)
          logger -t upssched-cmd "UPS comms lost for 60 seconds, initiating shutdown"
          /run/current-system/sw/bin/upsmon -c fsd
          ;;
        lowbatt)
          logger -t upssched-cmd "UPS battery critically low, immediate shutdown"
          /run/current-system/sw/bin/upsmon -c fsd
          ;;
        fsd)
          logger -t upssched-cmd "Forced shutdown received from UPS server"
          /run/current-system/sw/bin/upsmon -c fsd
          ;;
        *)
          logger -t upssched-cmd "Unrecognized command: $1"
          ;;
      esac
    '';
    mode = "0750";
    user = "root";
    group = "nut";
  };
}

