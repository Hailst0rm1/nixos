{
  lib,
  fetchFromGitHub,
  callPackage,
  stdenvNoCC,
  uv2nix,
  pyproject-nix,
  pyproject-build-systems,
}: let
  version = "5.19.3-unstable-2026-09-04";

  src = fetchFromGitHub {
    owner = "Alishahryar1";
    repo = "free-claude-code";
    # Upstream has no tags. Tracks main; bump SHA + hash to update.
    rev = "e6f2633b69694742232452c93b9785e44fbe684f";
    hash = "sha256-e5vnT1RG8KUAwPhqxufXUjHr67R0yCt+AI6+A8LiWoI=";
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
