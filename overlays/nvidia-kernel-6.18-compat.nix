final: prev: {
  linuxPackages = prev.linuxPackages.extend (lpfinal: lpprev: {
    nvidiaPackages = lpprev.nvidiaPackages // {
      mkDriver = args: (lpprev.nvidiaPackages.mkDriver args).overrideAttrs (oldAttrs: {
        patches = (oldAttrs.patches or []) ++ [
          ../patches/nvidia-open-kernel-6.18-compat.patch
        ];
      });
    };
  });
}
