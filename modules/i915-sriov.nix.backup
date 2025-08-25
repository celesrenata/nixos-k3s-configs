{ config, lib, pkgs, ... }:

{
  # Systemd service to enable Intel i915 SR-IOV virtual GPUs and configure VFIO
  systemd.services.i915-sriov-enable = {
    description = "Enable Intel i915 SR-IOV Virtual GPUs for VFIO passthrough";
    after = [ "multi-user.target" ];
    wantedBy = [ "multi-user.target" ];
    
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "enable-i915-sriov" ''
        # Enable SR-IOV (create 7 VFs)
        echo 7 > /sys/devices/pci0000:00/0000:00:02.0/sriov_numvfs
        
        # Wait for VFs to be created
        sleep 2
        
        # Bind VFs to vfio-pci driver for passthrough
        for vf in /sys/devices/pci0000:00/0000:00:02.0/virtfn*; do
          if [ -d "$vf" ]; then
            vf_pci=$(basename $(readlink $vf))
            echo "Configuring VF $vf_pci for VFIO passthrough"
            
            # Unbind from current driver if bound
            if [ -e "$vf/driver" ]; then
              echo $vf_pci > $vf/driver/unbind 2>/dev/null || true
            fi
            
            # Bind to vfio-pci
            echo "8086 7d55" > /sys/bus/pci/drivers/vfio-pci/new_id 2>/dev/null || true
            echo $vf_pci > /sys/bus/pci/drivers/vfio-pci/bind 2>/dev/null || true
          fi
        done
        
        echo "SR-IOV VFs configured for VFIO passthrough"
      '';
      
      ExecStop = pkgs.writeShellScript "disable-i915-sriov" ''
        # Disable SR-IOV
        echo 0 > /sys/devices/pci0000:00/0000:00:02.0/sriov_numvfs
      '';
    };
    
    # Only run if the SR-IOV sysfs file exists
    unitConfig = {
      ConditionPathExists = "/sys/devices/pci0000:00/0000:00:02.0/sriov_numvfs";
    };
  };
}
