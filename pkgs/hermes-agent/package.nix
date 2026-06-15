{
  lib,
  stdenv,
  fetchFromGitHub,
  python3,
  uv,
  cacert,
  git,
  nodejs,
  buildNpmPackage,
  fetchNpmDeps,
  diffutils,
  makeWrapper,
  ripgrep,
  ffmpeg,
  openssh,
}: let
  version = "2026.6.5";
  python = python3;
  pip = python3.pkgs.pip;

  src = fetchFromGitHub {
    owner = "NousResearch";
    repo = "hermes-agent";
    # Upstream now publishes CalVer release tags; pin to the latest stable tag.
    # Bump rev + hash to pull new upstream releases.
    rev = "v${version}";
    hash = "sha256-ngpkopVczNrT0bfCXHm38QjgrZT96Bm/rO89NA/ls3Y=";
  };

  # FOD: download all Python wheels/sdists via pip
  hermes-wheels = stdenv.mkDerivation {
    pname = "hermes-agent-wheels";
    inherit version src;

    nativeBuildInputs = [python pip cacert git];

    buildPhase = ''
      export HOME=$TMPDIR
      export SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt

      ${python}/bin/python3 -m pip download ".[all,messaging]" setuptools wheel \
        --dest $out
    '';

    dontInstall = true;
    dontFixup = true;

    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-J7DmgeoBzLIawyCFtbAfwEJ/oLY7u8ATyq3oJqrve50=";
  };

  # Single npm-deps fetch from the workspace root package-lock.json. Upstream
  # moved web/ (and apps/desktop) into one npm workspace, so the dashboard
  # frontend is now built via buildNpmPackage against the root lockfile rather
  # than a per-folder `npm ci`. Matches pkgs/hermes-desktop/package.nix.
  npmDepsHash = "sha256-hgnqcpKRPztHhDEpwC7HJrALuJp9wsrV4+GJ6t6HI2c=";

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

    nativeBuildInputs = [python uv makeWrapper pip];

    buildPhase = ''
      export HOME=$TMPDIR

      # Install Python package
      ${python}/bin/python3 -m venv $TMPDIR/.venv
      $TMPDIR/.venv/bin/pip install ".[all,messaging]" \
        --no-index \
        --find-links ${hermes-wheels}

      # Guard against response.output being None in openai SDK
      substituteInPlace $TMPDIR/.venv/lib/python3.13/site-packages/openai/lib/_parsing/_responses.py \
        --replace-fail \
          'for output in response.output:' \
          'for output in (response.output or []):'
    '';

    installPhase = ''
      mkdir -p $out
      cp -r $TMPDIR/.venv/* $out/

      # Copy the separately-built web dashboard into site-packages. The
      # dashboard serves this (HERMES_WEB_DIST defaults to web_dist), and it's
      # what the desktop client connects to.
      cp -r ${hermes-web} $out/lib/python3.13/site-packages/hermes_cli/web_dist

      # Upstream's pyproject `setuptools.packages.find` lists `hermes_cli`
      # without `hermes_cli.*`, so sub-packages (dashboard_auth, proxy) are
      # excluded from the wheel and `hermes dashboard` fails with
      # ModuleNotFoundError. Copy them in manually until upstream fixes
      # the include pattern.
      for sub in dashboard_auth proxy; do
        if [ -d "$src/hermes_cli/$sub" ]; then
          cp -r "$src/hermes_cli/$sub" "$out/lib/python3.13/site-packages/hermes_cli/$sub"
        fi
      done

      # Bundle repo-level skill / plugin trees so hermes can find them.
      # Upstream's own Nix packaging exposes these via HERMES_BUNDLED_SKILLS
      # / HERMES_OPTIONAL_SKILLS / HERMES_BUNDLED_PLUGINS env vars.
      mkdir -p $out/share/hermes-agent
      cp -r $src/skills           $out/share/hermes-agent/skills
      cp -r $src/optional-skills  $out/share/hermes-agent/optional-skills
      cp -r $src/plugins          $out/share/hermes-agent/plugins

      # Fix shebangs to reference $out
      find $out/bin -type f -exec sed -i "s|$TMPDIR/.venv|$out|g" {} +

      # Wrap with runtime deps + bundled-content env vars
      for cmd in hermes hermes-agent hermes-acp; do
        if [ -f "$out/bin/$cmd" ]; then
          wrapProgram $out/bin/$cmd \
            --prefix PATH : ${lib.makeBinPath [ripgrep ffmpeg git nodejs openssh]} \
            --set HERMES_BUNDLED_SKILLS  $out/share/hermes-agent/skills \
            --set HERMES_OPTIONAL_SKILLS $out/share/hermes-agent/optional-skills \
            --set HERMES_BUNDLED_PLUGINS $out/share/hermes-agent/plugins
        fi
      done
    '';

    meta = with lib; {
      description = "Self-improving AI agent by Nous Research";
      homepage = "https://github.com/NousResearch/hermes-agent";
      license = licenses.mit;
      maintainers = [];
      platforms = platforms.linux;
      mainProgram = "hermes";
    };
  }
