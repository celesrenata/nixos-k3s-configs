final: prev: {
  linuxPackages = prev.linuxPackages.extend (lpfinal: lpprev: {
    nvidiaPackages = lpprev.nvidiaPackages // {
      mkDriver = args: (lpprev.nvidiaPackages.mkDriver args).overrideAttrs (oldAttrs: {
        postPatch = (oldAttrs.postPatch or "") + ''
          sed -i 's/get_dev_pagemap(page_to_pfn(page), NULL)/get_dev_pagemap(page_to_pfn(page))/g' kernel-open/nvidia-uvm/uvm_va_range_device_p2p.c
        '';
      });
    };
  });
}
