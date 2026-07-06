{
  lib,
  stdenv,
  fetchFromGitHub,
  callPackage,
  nodejs,
  buildNpmPackage,
  fetchNpmDeps,
  diffutils,
  makeWrapper,
  ripgrep,
  ffmpeg,
  git,
  openssh,
  # Flake inputs threaded in via the overlay (overlays/hermes-agent.nix) or
  # explicitly from flake.nix's packages output. Drive the uv2nix venv build.
  uv2nix,
  pyproject-nix,
  pyproject-build-systems,
}: let
  version = "2026.7.1";

  src = fetchFromGitHub {
    owner = "NousResearch";
    repo = "hermes-agent";
    # Upstream now publishes CalVer release tags; pin to the latest stable tag.
    # Bump rev + hash to pull new upstream releases.
    rev = "v${version}";
    hash = "sha256-Wt72AQtA6Eizi7Ubj23JBhwZ7GKYcjY4mcV6upqHOaU=";
  };

  # Python environment built from upstream's uv.lock via uv2nix — deterministic,
  # no live PyPI resolution, no drifting hash. See ./python.nix.
  hermesVenv = callPackage ./python.nix {
    inherit uv2nix pyproject-nix pyproject-build-systems src;
  };

  # Single npm-deps fetch from the workspace root package-lock.json. Upstream
  # moved web/ (and apps/desktop) into one npm workspace, so the dashboard
  # frontend is now built via buildNpmPackage against the root lockfile rather
  # than a per-folder `npm ci`. Matches pkgs/hermes-desktop/package.nix.
  npmDepsHash = "sha256-qDXGL/INHPW0pTF4SRVL1dS5XVh2X85dEE4JhrAQeqU=";

  npmDeps = fetchNpmDeps {
    inherit src;
    fetcherVersion = 2;
    hash = npmDepsHash;
  };

  # Build the web dashboard frontend (Vite/React) → web/dist. Ported from
  # upstream nix/web.nix; the newline-normalising patchPhase comes from
  # nix/lib.nix so npmConfigHook's lockfile diff stays happy.
  hermes-web = buildNpmPackage {
    pname = "hermes-web";
    inherit version src npmDeps nodejs;

    npmRoot = ".";
    npmDepsFetcherVersion = 2;
    makeCacheWritable = true;
    doCheck = false;
    npmFlags = ["--ignore-scripts"];

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
      # Build from web/ so vite.config.ts/tsconfig resolve; root node_modules
      # is at ../node_modules. vite.config.ts's outDir points at
      # ../hermes_cli/web_dist for the monorepo, so override to dist/.
      cd web
      node ../node_modules/typescript/bin/tsc -b
      node ../node_modules/vite/bin/vite.js build --outDir dist
      cd ..
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      cp -r web/dist $out
      runHook postInstall
    '';
  };
in
  stdenv.mkDerivation {
    pname = "hermes-agent";
    inherit version src;

    # The venv is prebuilt by uv2nix; we only assemble the wrapper + bundled
    # content, so there's nothing to unpack or compile here.
    dontUnpack = true;
    dontBuild = true;

    nativeBuildInputs = [makeWrapper];

    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/hermes-agent $out/bin

      # Bundle the separately-built dashboard and the repo-level skill / plugin
      # trees. Upstream's packaging points the runtime at these via env vars
      # (HERMES_WEB_DIST / HERMES_BUNDLED_SKILLS / HERMES_OPTIONAL_SKILLS /
      # HERMES_BUNDLED_PLUGINS) rather than writing into the sealed venv.
      cp -r ${hermes-web}        $out/share/hermes-agent/web_dist
      cp -r $src/skills          $out/share/hermes-agent/skills
      cp -r $src/optional-skills $out/share/hermes-agent/optional-skills
      cp -r $src/plugins         $out/share/hermes-agent/plugins

      # Wrap the uv2nix venv entrypoints with runtime deps + bundled-content env
      # vars. Wrapping (vs copying the venv) keeps the dependency closure sealed.
      for cmd in hermes hermes-agent hermes-acp; do
        if [ -e "${hermesVenv}/bin/$cmd" ]; then
          makeWrapper ${hermesVenv}/bin/$cmd $out/bin/$cmd \
            --prefix PATH : ${lib.makeBinPath [ripgrep ffmpeg git nodejs openssh]} \
            --set HERMES_WEB_DIST        $out/share/hermes-agent/web_dist \
            --set HERMES_BUNDLED_SKILLS  $out/share/hermes-agent/skills \
            --set HERMES_OPTIONAL_SKILLS $out/share/hermes-agent/optional-skills \
            --set HERMES_BUNDLED_PLUGINS $out/share/hermes-agent/plugins
        fi
      done

      runHook postInstall
    '';

    # `src` is already exposed as a derivation attr (hermes-desktop reuses
    # `hermes-agent.src`); expose the build intermediates for debugging.
    passthru = {inherit hermesVenv hermes-web;};

    meta = with lib; {
      description = "Self-improving AI agent by Nous Research";
      homepage = "https://github.com/NousResearch/hermes-agent";
      license = licenses.mit;
      maintainers = [];
      platforms = platforms.linux;
      mainProgram = "hermes";
    };
  }
