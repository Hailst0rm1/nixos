final: prev: {
  pythonPackagesExtensions =
    (prev.pythonPackagesExtensions or [])
    ++ [
      (_pythonFinal: pythonPrev: {
        imageio = pythonPrev.imageio.overridePythonAttrs (old: {
          # imageio 2.37.2's 16-bit PNG tests break on newer Pillow
          # ("ValueError: Invalid mode for data type"). Drop once nixpkgs fixes it.
          disabledTestPaths =
            (old.disabledTestPaths or [])
            ++ [
              "tests/test_pillow.py::test_png_16bit"
              "tests/test_pillow_legacy.py::test_png"
            ];
        });
      })
    ];
}
