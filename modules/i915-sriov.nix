{ config, lib, pkgs, inputs, ... }:

{
  # Intel i915 SR-IOV configuration
  # The actual SR-IOV functionality is provided by the i915-sriov DKMS module

  # i915 SR-IOV kernel parameters (iommu params are in boot.nix)
  boot.kernelParams = [
    "i915.enable_guc=3"
    "i915.max_vfs=7"
    "i915.force_probe=7d55"
    "module_blacklist=xe"
    # arc-embed-ceiling-boost / FEAT-001: fix the Meteor Lake Arc SR-IOV compute
    # hang. Under sustained OVMS inference the VF compute command streamer (ccs0)
    # wedged, flooding "GT0: Unexpected memirq status 0x0 from ccs0" and timing
    # out GPU fences ("Fence expiration time out ... ovms[...]"), which hung the
    # embedding endpoint. The default engine-first reset (reset=2, part of the
    # 0x3 bitmask) does NOT recover the wedged compute engine on these VFs, so
    # the hang persisted. Force a full-GPU reset (reset=1) so a wedged batch is
    # cleared completely instead of storming, and tighten the request/fence
    # expiration so a hang is detected and reset promptly rather than wedging the
    # whole engine. Reversible: revert to the engine-reset default by removing
    # these two lines.
    "i915.reset=1"
    "i915.request_timeout_ms=10000"
  ];

  # Enable VFIO kernel modules
  boot.kernelModules = [ "vfio" "vfio_iommu_type1" "vfio_pci" ];
}
