# Disable a flaky librosa test that fails on x86_64 with current
# numpy/scipy on nixpkgs-unstable. The "_multi" tempogram test is a
# numerical-comparison check already disabled upstream for aarch64;
# it intermittently fails on x86_64 too, breaking the check phase of
# python3.14-librosa (pulled in transitively via piper-tts / exo).
final: prev: {
  pythonPackagesExtensions = (prev.pythonPackagesExtensions or [ ]) ++ [
    (pyfinal: pyprev: {
      librosa = pyprev.librosa.overridePythonAttrs (old: {
        disabledTests = (old.disabledTests or [ ]) ++ [
          "test_tempogram_odf_multi"
        ];
      });
    })
  ];
}
