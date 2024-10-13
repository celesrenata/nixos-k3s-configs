final: prev: {
  libuv = prev.libuv.overrideAttrs (old: {
    doCheck = false;
    postPatch = (old.postPatch or "") + ''
      sed '/fs_utime_round/d' -i test/test-list.h
      sed '/queue_foreach_delete/d' -i test/test-list.h
      sed '/fs_event_.*/d' -i test/test-list.h
    '';
  });
}
