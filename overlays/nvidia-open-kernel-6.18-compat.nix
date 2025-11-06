final: prev: {
  linuxPackages = prev.linuxPackages.extend (lpfinal: lpprev: {
    nvidiaPackages = lpprev.nvidiaPackages // {
      stable = lpprev.nvidiaPackages.stable.overrideAttrs (oldAttrs: {
        patches = (oldAttrs.patches or []) ++ [
          /etc/nixos/patches/nvidia-open-kernel-6.18-compat.patch
        ];
      });
    };
  });
}
