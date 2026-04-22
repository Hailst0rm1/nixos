{
  lib,
  fetchFromGitHub,
  stdenv,
  bun,
  makeWrapper,
  nodejs,
  cacert,
}: let
  # Pre-fetch node_modules as a fixed-output derivation
  bun-modules = stdenv.mkDerivation {
    pname = "the-vibe-companion-bun-modules";
    version = "0.95.0";

    src = fetchFromGitHub {
      owner = "The-Vibe-Company";
      repo = "companion";
      rev = "the-companion-v0.95.0";
      hash = "sha256-JJyoD1sUKQ9OaJgfmoHFTx+B0rMUijS0/F6TSFtlIgU=";
    };

    nativeBuildInputs = [bun cacert nodejs];

    buildPhase = ''
      cd web
      export HOME=$TMPDIR
      export BUN_INSTALL=$TMPDIR/.bun
      export BUN_RUNTIME_TRANSPILER_CACHE_PATH=$TMPDIR/.bun-cache
      bun install --no-save --frozen-lockfile
    '';

    installPhase = ''
      mkdir -p $out
      cp -r node_modules $out/
      cp package.json $out/
      [[ -f bun.lock ]] && cp bun.lock $out/ || true
    '';

    dontFixup = true;

    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-tSDdYxL15wq7BgQ5o0LeBcwvXM7EbjyoB8EzhSl4kNY=";
  };
in
  stdenv.mkDerivation rec {
    pname = "the-vibe-companion";
    version = "0.95.0";

    src = fetchFromGitHub {
      owner = "The-Vibe-Company";
      repo = "companion";
      rev = "the-companion-v${version}";
      hash = "sha256-JJyoD1sUKQ9OaJgfmoHFTx+B0rMUijS0/F6TSFtlIgU=";
    };

    nativeBuildInputs = [
      bun
      makeWrapper
      nodejs
    ];

    buildInputs = [
      bun
    ];

    preBuild = ''
      cd web
      export HOME=$TMPDIR
      export BUN_INSTALL=$TMPDIR/.bun
      export BUN_RUNTIME_TRANSPILER_CACHE_PATH=$TMPDIR/.bun-cache

      # Copy pre-fetched node_modules
      cp -r ${bun-modules}/node_modules .
      chmod -R +w node_modules

      # Patch shebangs in node_modules binaries
      patchShebangs node_modules
    '';

    buildPhase = ''
      runHook preBuild

      # Build the frontend (dependencies already installed)
      bun run build

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/lib/the-vibe-companion
      mkdir -p $out/bin

      # Copy the built application
      cp -r dist $out/lib/the-vibe-companion/
      cp -r server $out/lib/the-vibe-companion/
      cp -r bin $out/lib/the-vibe-companion/
      cp -r node_modules $out/lib/the-vibe-companion/
      cp package.json $out/lib/the-vibe-companion/

      # Create wrapper script that uses bun
      makeWrapper ${bun}/bin/bun $out/bin/the-vibe-companion \
        --add-flags "$out/lib/the-vibe-companion/bin/cli.ts" \
        --set NODE_ENV production \
        --set __VIBE_PACKAGE_ROOT "$out/lib/the-vibe-companion"

      runHook postInstall
    '';

    doCheck = false;

    meta = with lib; {
      description = "Web UI for launching and interacting with Claude Code agents";
      longDescription = ''
        The Vibe Companion is a web UI that lets you run multiple Claude Code sessions
        simultaneously. It provides real-time streaming of responses, visual feedback on
        tool calls, and permission controls.
      '';
      homepage = "https://github.com/The-Vibe-Company/companion";
      license = licenses.mit;
      maintainers = [];
      platforms = platforms.linux ++ platforms.darwin;
      mainProgram = "the-vibe-companion";
    };
  }
