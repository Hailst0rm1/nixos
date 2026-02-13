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
    version = "0.31.0";

    src = fetchFromGitHub {
      owner = "The-Vibe-Company";
      repo = "companion";
      rev = "the-companion-v0.31.0";
      hash = "sha256-ZqYhh4wyH8BrDt/WU0Hj4/7413aO07Uh0maYbIcqO4Q=";
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

    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-npP3DST7+cwtk237w0mUtLHluWuT37CXYZ6PDERM9/c=";
  };
in
  stdenv.mkDerivation rec {
    pname = "the-vibe-companion";
    version = "0.31.0";

    src = fetchFromGitHub {
      owner = "The-Vibe-Company";
      repo = "companion";
      rev = "the-companion-v${version}";
      hash = "sha256-ZqYhh4wyH8BrDt/WU0Hj4/7413aO07Uh0maYbIcqO4Q=";
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

    # Tests require a full build environment and API keys
    doCheck = false;

    meta = with lib; {
      description = "Web UI for launching and interacting with Claude Code agents";
      longDescription = ''
        The Vibe Companion is a web UI that lets you run multiple Claude Code sessions
        simultaneously. It provides real-time streaming of responses, visual feedback on
        tool calls, and permission controls. The application reverse-engineered the
        undocumented WebSocket protocol used by Claude Code CLI to provide a browser-based
        interface for agent interactions.

        Features:
        - Multiple concurrent Claude Code sessions
        - Real-time streaming responses
        - Tool call visibility with approval controls
        - Session persistence and auto-recovery
        - Environment profile management
        - Git worktree integration
      '';
      homepage = "https://github.com/The-Vibe-Company/companion";
      license = licenses.mit;
      maintainers = [];
      platforms = platforms.linux ++ platforms.darwin;
      mainProgram = "the-vibe-companion";
    };
  }
