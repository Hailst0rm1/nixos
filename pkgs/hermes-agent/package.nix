{
  lib,
  stdenv,
  fetchFromGitHub,
  python3,
  uv,
  cacert,
  git,
  nodejs,
  makeWrapper,
  ripgrep,
  ffmpeg,
  openssh,
}: let
  version = "0.15.1";
  python = python3;
  pip = python3.pkgs.pip;

  src = fetchFromGitHub {
    owner = "NousResearch";
    repo = "hermes-agent";
    rev = "v2026.5.29.2";
    hash = "sha256-0CmNH879jnsAAszo1nkkFm8RNE49xtwUditYdFIYBCM=";
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
    outputHash = "sha256-036d1dkD6bMwM0OYJ/xUvZjuS6EQC+OIvvVhCgCKBuo=";
  };

  # FOD: pre-fetch node_modules for web dashboard
  hermes-web-modules = stdenv.mkDerivation {
    pname = "hermes-agent-web-modules";
    inherit version src;

    nativeBuildInputs = [nodejs cacert];

    buildPhase = ''
      cd web
      export HOME=$TMPDIR
      npm ci --ignore-scripts
    '';

    installPhase = ''
      mkdir -p $out
      cp -r node_modules $out/
      cp package.json $out/
      cp package-lock.json $out/
    '';

    dontFixup = true;

    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-/H/u2HA+04u0Olus3QByBr9faR07trIfFAKK/D49XFM=";
  };
in
  stdenv.mkDerivation {
    pname = "hermes-agent";
    inherit version src;

    nativeBuildInputs = [python uv makeWrapper pip nodejs];

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

      # Build web dashboard frontend
      cp -r web $TMPDIR/web
      mkdir -p $TMPDIR/hermes_cli
      cp -r ${hermes-web-modules}/node_modules $TMPDIR/web/
      chmod -R +w $TMPDIR/web/node_modules
      patchShebangs $TMPDIR/web/node_modules
      cd $TMPDIR/web && npm run build
    '';

    installPhase = ''
      mkdir -p $out
      cp -r $TMPDIR/.venv/* $out/

      # Copy built web dashboard into site-packages
      cp -r $TMPDIR/hermes_cli/web_dist $out/lib/python3.13/site-packages/hermes_cli/web_dist

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
