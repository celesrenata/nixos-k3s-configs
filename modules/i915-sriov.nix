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
    "i915.request_timeout_ms=30000"
  ];

  # xelp_enable_ccs: DELIBERATELY UNSET. Since 2026.09.16/2025.12.10.1, ccs0
  # is off by default on Xe_LP VFs (upstream dropped it; the repo made it a
  # tri-state opt-in — see strongtz/i915-sriov-dkms#498). LNL 7d55 is Xe_LP, so
  # we are in scope, but we do NOT set i915.xelp_enable_ccs=1 because:
  #   1. ccs0 on Xe_LP is a non-POR engine Intel never formally supported —
  #      the FEAT-001 wedge above is this engine faulting, not a bug to patch.
  #   2. Inference runs on the host PF (ovms-embeddings-host.nix / arcforge),
  #      so no host-side component needs a VF compute engine.
  #   3. Enabling it only re-exposes the non-POR engine to VFs; #510 shows
  #      Xe_LP VFs still hang (GPU HANG ecode 12:1) under heavy workloads even
  #      with CCS enabled — it is a partial, workload-dependent fix, not a
  #      stable one.
  # The pinned 2026.11.05 already carries the related VF-hang workarounds:
  # the 47-bit PPGTT restriction for CCS-enabled hosts (commit b93d4c2e) and
  # the Xe LRC workarounds for Xe_LP VFs (commit af43f687, closes #486/#506).
  # reset=1 above remains the recovery path if a VF ever wedges anyway.

  # Enable VFIO kernel modules
  boot.kernelModules = [ "vfio" "vfio_iommu_type1" "vfio_pci" ];
}
