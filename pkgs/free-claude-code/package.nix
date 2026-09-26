{
  lib,
  fetchFromGitHub,
  callPackage,
  stdenvNoCC,
  uv2nix,
  pyproject-nix,
  pyproject-build-systems,
}: let
  version = "6.2.71";

  src = fetchFromGitHub {
    owner = "Alishahryar1";
    repo = "free-claude-code";
    # Upstream now publishes release tags; pin to the latest stable one.
    # Bump rev + hash to pull new upstream releases.
    rev = "v${version}";
    hash = "sha256-LJQ/XKjmCYpRoXd7fvOF7nyiYTURdKIfGgmtEo3PFtU=";
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
