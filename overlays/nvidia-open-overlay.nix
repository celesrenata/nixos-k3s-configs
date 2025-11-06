final: prev: {
  linuxPackages = prev.linuxPackages.extend (lpfinal: lpprev: {
    nvidiaPackages = lpprev.nvidiaPackages // {
      stable = lpprev.nvidiaPackages.stable.overrideAttrs (oldAttrs: {
        open = oldAttrs.open.overrideAttrs (openAttrs: {
          postPatch = (openAttrs.postPatch or "") + ''
            substituteInPlace kernel-open/nvidia-uvm/uvm_va_range_device_p2p.c \
              --replace 'get_dev_pagemap(page_to_pfn(page), NULL)' 'get_dev_pagemap(page_to_pfn(page))'
          '';
        });
      });
    };
  });
}
