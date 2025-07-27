{ config, lib, pkgs, inputs, ... }:

{
  # Patched i915-sriov with comprehensive fixes for kernel 6.15.7
  # This module provides the patched driver for all systems
  
  nixpkgs.overlays = [
    (final: prev: {
      i915-sriov-patched = prev.stdenv.mkDerivation {
        name = "i915-sriov-${config.boot.kernelPackages.kernel.modDirVersion}";
        src = inputs.i915-sriov;
        hardeningDisable = [ "pic" ];
        nativeBuildInputs = config.boot.kernelPackages.kernel.moduleBuildDependencies;
        
        # Apply comprehensive patches inline
        patchPhase = ''
          echo "Applying comprehensive fixes for kernel 6.15.7"
          
          # 1. Runtime PM API fix
          cat > runtime-pm-fix.patch << 'EOF'
--- a/drivers/gpu/drm/i915/intel_runtime_pm.c
+++ b/drivers/gpu/drm/i915/intel_runtime_pm.c
@@ -250,7 +250,7 @@ static intel_wakeref_t __intel_runtime_pm_get_if_active(struct intel_runtime_pm
 		 * function, since the power state is undefined. This applies
 		 * atm to the late/early system suspend/resume handlers.
 		 */
-#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 9 ,0) || (defined (_CONFIGURE_PM_RUNTIME_GET_IF_ACTIVE) && _CONFIGURE_PM_RUNTIME_GET_IF_ACTIVE >= KERNEL_VERSION(6, 9, 0))
+#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 15, 0)
 		if ((ignore_usecount &&
 		     pm_runtime_get_if_active(rpm->kdev) <= 0) ||
 		    (!ignore_usecount &&
EOF
          
          # 2. Memory safety fix for gen6_gmch_remove
          cat > memory-safety-fix.patch << 'EOF'
--- a/drivers/gpu/drm/i915/gt/intel_ggtt.c
+++ b/drivers/gpu/drm/i915/gt/intel_ggtt.c
@@ -1252,7 +1252,10 @@ static int gen6_gmch_probe(struct i915_ggtt *ggtt)
 static void gen6_gmch_remove(struct i915_address_space *vm)
 {
 	struct i915_ggtt *ggtt = i915_vm_to_ggtt(vm);
-
-	iounmap(ggtt->gsm);
+	
+	if (ggtt->gsm) {
+		iounmap(ggtt->gsm);
+		ggtt->gsm = NULL;
+	}
 	free_scratch(vm);
 }
EOF
          
          echo "Applying runtime PM fix..."
          patch -p1 < runtime-pm-fix.patch
          
          echo "Applying memory safety fix..."
          patch -p1 < memory-safety-fix.patch
        '';
        
        makeFlags = [
          "KVERSION=${config.boot.kernelPackages.kernel.modDirVersion}"
          "KDIR=${config.boot.kernelPackages.kernel.dev}/lib/modules/${config.boot.kernelPackages.kernel.modDirVersion}/build"
        ];
        buildPhase = ''
          echo "Building comprehensively patched i915-sriov for kernel ${config.boot.kernelPackages.kernel.modDirVersion}"
          make -j$NIX_BUILD_CORES -C ${config.boot.kernelPackages.kernel.dev}/lib/modules/${config.boot.kernelPackages.kernel.modDirVersion}/build M=$(pwd) modules
        '';
        installPhase = ''
          install -D i915.ko $out/lib/modules/${config.boot.kernelPackages.kernel.modDirVersion}/kernel/drivers/gpu/drm/i915/i915.ko
        '';
      };
    })
  ];

  # Enable Intel SR-IOV support with comprehensive patches
  boot.extraModulePackages = [ pkgs.i915-sriov-patched ];
}
