{
  lib,
  buildGoModule,
  fetchFromGitHub,
  makeWrapper,
  python3,
  volatility3,
}: let
  # volatility3 is packaged as an application; re-expose it as a module so the
  # inventory script's API collector can import it from sys.executable.
  python = python3.withPackages (ps: [(ps.toPythonModule volatility3)]);
in
  buildGoModule {
    pname = "vol-wrapper";
    version = "0-unstable-2026-09-22";

    src = fetchFromGitHub {
      owner = "BeanBagKing";
      repo = "VolGolangWrapper";
      # track-branch: main
      rev = "6876e05271e0049c73d76a28455b1d8ac34f1242";
      hash = "sha256-uTTSQDYOJVwNapc9GmoxHXNwB9wLW2aMRoFPSfg98FQ=";
    };

    vendorHash = "sha256-Z8V1a3uJdG/lj6AP4Xly01MQSq/yBnB2/TuERrrj0o0=";

    nativeBuildInputs = [makeWrapper];

    ldflags = ["-s" "-w"];

    postInstall = ''
      mv $out/bin/VolGolangWrapper $out/bin/vol-wrapper
      # --suffix: an activated venv or a vol earlier on PATH still wins.
      wrapProgram $out/bin/vol-wrapper --suffix PATH : ${volatility3}/bin

      install -Dm755 vol_plugin_inventory.py $out/libexec/vol-plugin-inventory
      makeWrapper ${python}/bin/python $out/bin/vol-plugin-inventory \
        --add-flags $out/libexec/vol-plugin-inventory
    '';

    meta = {
      description = "Run Volatility 3 plugins in parallel against a memory image, one output file per plugin";
      homepage = "https://github.com/BeanBagKing/VolGolangWrapper";
      # No license file upstream.
      license = lib.licenses.unfree;
      mainProgram = "vol-wrapper";
      platforms = lib.platforms.unix;
    };
  }
