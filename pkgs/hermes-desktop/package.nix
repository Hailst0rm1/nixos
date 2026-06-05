# Hermes Desktop — native Electron shell for the Hermes agent.
#
# Ported from upstream nix/desktop.nix + the npm-workspace plumbing in
# nix/lib.nix (mkNpmPassthru). We reuse `hermes-agent.src` so the desktop
# tracks the exact same upstream checkout as the agent (single source of
# truth for rev/hash), and point the desktop at our fully-wrapped `hermes`
# binary via HERMES_DESKTOP_HERMES so its backend resolver uses the agent
# with venv + bundled skills/plugins + runtime PATH already wired up.
{
  lib,
  stdenv,
  buildNpmPackage,
  fetchNpmDeps,
  makeWrapper,
  electron_40,
  nodejs_22,
  diffutils,
  hermes-agent,
}: let
  nodejs = nodejs_22;
  electron = electron_40;
  src = hermes-agent.src;
  version = "0.15.1-unstable-2026-06-04";

  # Single npm-deps fetch from the workspace root package-lock.json.
  # Matches upstream nix/lib.nix for the same main checkout; if Nix reports
  # a mismatch after a rev bump, paste the "got:" hash here.
  npmDepsHash = "sha256-9xW/kVb315Cdx5mbn3zBIaNuaJB6yKKh2F5I0QCZ1ow=";

  npmDeps = fetchNpmDeps {
    inherit src;
    fetcherVersion = 2;
    hash = npmDepsHash;
  };

  # Build the Electron renderer (dist/ + electron/ + package.json).
  renderer = buildNpmPackage {
    pname = "hermes-desktop-renderer";
    inherit version src npmDeps nodejs;

    npmRoot = ".";
    npmDepsFetcherVersion = 2;
    makeCacheWritable = true;
    doCheck = false;

    # --ignore-scripts: the workspace includes electron (apps/desktop) whose
    # postinstall downloads from github.com; nix builds are offline. Each
    # phase sets up its own build commands instead.
    npmFlags = ["--ignore-scripts"];

    # Normalize trailing newlines on the root lockfile so the source and the
    # npm-deps cache always match, and make npmConfigHook's byte-for-byte
    # diff newline-agnostic (ported verbatim from upstream nix/lib.nix).
    patchPhase = ''
      runHook prePatch
      sed -i -z 's/\\n*$/\\n/' package-lock.json

      mkdir -p "$TMPDIR/bin"
      cat > "$TMPDIR/bin/diff" << DIFFWRAP
      #!/bin/sh
      f1=\\$(mktemp) && sed -z 's/\\n*$/\\n/' "\\$1" > "\\$f1"
      f2=\\$(mktemp) && sed -z 's/\\n*$/\\n/' "\\$2" > "\\$f2"
      ${diffutils}/bin/diff "\\$f1" "\\$f2" && rc=0 || rc=\\$?
      rm -f "\\$f1" "\\$f2"
      exit \\$rc
      DIFFWRAP
      chmod +x "$TMPDIR/bin/diff"
      export PATH="$TMPDIR/bin:$PATH"
      runHook postPatch
    '';

    buildPhase = ''
      runHook preBuild

      # write-build-stamp.cjs replacement — informational in nix builds
      # (the backend comes from the derivation directly).
      mkdir -p apps/desktop/build
      echo '{"schemaVersion":1,"commit":"nix","branch":"nix","dirty":false,"source":"nix"}' > apps/desktop/build/install-stamp.json

      # Build from apps/desktop so vite.config.ts resolves correctly; the
      # workspace root node_modules is reachable as ../../node_modules.
      # vite transpiles TS via esbuild, so we skip `tsc -b` (its only purpose
      # here is type-checking, which fails on test-only files that don't ship).
      cd apps/desktop
      node ../../node_modules/vite/bin/vite.js build --outDir dist
      cd ../..

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r apps/desktop/dist $out/
      cp -r apps/desktop/electron $out/
      cp -r apps/desktop/build $out/
      cp apps/desktop/package.json $out/
      runHook postInstall
    '';
  };
in
  stdenv.mkDerivation {
    pname = "hermes-desktop";
    inherit version;

    dontUnpack = true;
    dontBuild = true;

    nativeBuildInputs = [makeWrapper];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/share/hermes-desktop $out/bin
      cp -r ${renderer}/* $out/share/hermes-desktop/

      # Wrap nixpkgs electron pointed at our renderer dir. HERMES_DESKTOP_HERMES
      # makes the desktop's backend resolver use our fully-wrapped `hermes`.
      makeWrapper ${lib.getExe electron} $out/bin/hermes-desktop \
        --add-flags "$out/share/hermes-desktop" \
        --set HERMES_DESKTOP_HERMES "${lib.getExe hermes-agent}" \
        --set ELECTRON_IS_DEV 0

      runHook postInstall
    '';

    meta = with lib; {
      description = "Native Electron desktop shell for Hermes Agent";
      homepage = "https://github.com/NousResearch/hermes-agent";
      license = licenses.mit;
      maintainers = [];
      platforms = platforms.linux;
      mainProgram = "hermes-desktop";
    };
  }
