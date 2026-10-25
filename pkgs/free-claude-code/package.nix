{
  lib,
  fetchFromGitHub,
  callPackage,
  stdenvNoCC,
  uv2nix,
  pyproject-nix,
  pyproject-build-systems,
}: let
  version = "6.16.18";

  src = fetchFromGitHub {
    owner = "Alishahryar1";
    repo = "free-claude-code";
    # Upstream now publishes release tags; pin to the latest stable one.
    # Bump rev + hash to pull new upstream releases.
    # Capped at 6.16.18: v6.16.19+ pin requires-python == 3.14.9, but nixpkgs
    # python314 is 3.14.7. Bump past 6.16.18 once nixpkgs ships 3.14.9.
    rev = "v${version}";
    hash = "sha256-E9pTOjylaCjfGL0iTboP2BNdJXjKdEI1E3obK2YMaWo=";
  };

  venv = callPackage ./python.nix {
    inherit src uv2nix pyproject-nix pyproject-build-systems;
  };
in
  stdenvNoCC.mkDerivation {
    pname = "free-claude-code";
    inherit version;

    dontUnpack = true;

    installPhase = ''
      mkdir -p $out/bin
      ln -s ${venv}/bin/fcc-* $out/bin/
    '';

    meta = {
      description = "Local proxy connecting coding agents to free and compatible AI providers";
      homepage = "https://github.com/Alishahryar1/free-claude-code";
      license = lib.licenses.mit;
      mainProgram = "fcc-server";
      platforms = lib.platforms.linux;
    };
  }
