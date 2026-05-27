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
  version = "0.13.0";
  python = python3;
  pip = python3.pkgs.pip;

  src = fetchFromGitHub {
    owner = "NousResearch";
    repo = "hermes-agent";
    rev = "v2026.5.7";
    hash = "sha256-YQQUEDUim2CiYpL3uG7Wi1fWPsT2wtIqoBeJuAj9hUk=";
  };

  # FOD: download all Python wheels/sdists via pip
  hermes-wheels = stdenv.mkDerivation {
    pname = "hermes-agent-wheels";
    inherit version src;

    nativeBuildInputs = [python pip cacert git];

    buildPhase = ''
      export HOME=$TMPDIR
      export SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt

      ${python}/bin/python3 -m pip download ".[all]" \
        --dest $out
    '';

    dontInstall = true;
    dontFixup = true;

    outputHashMode = "recursive";
    outputHashAlgo = "sha256";
    outputHash = "sha256-tuz0SH0sGLh0ZoKhRRLrihB3DIbLpOsmQHx5+YJqW9M=";
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
    outputHash = "sha256-xUAUcnU/zZG5ysxa2lJcMJ5GmfwccsT/9WiOE8Q7HAk=";
  };
in
  stdenv.mkDerivation {
    pname = "hermes-agent";
    inherit version src;

    nativeBuildInputs = [python uv makeWrapper pip nodejs];

    patches = [./codex-transport-tools-none.patch];

    buildPhase = ''
      export HOME=$TMPDIR

      # Install Python package
      ${python}/bin/python3 -m venv $TMPDIR/.venv
      $TMPDIR/.venv/bin/pip install ".[all]" \
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

      # Fix shebangs to reference $out
      find $out/bin -type f -exec sed -i "s|$TMPDIR/.venv|$out|g" {} +

      # Wrap with runtime deps
      for cmd in hermes hermes-agent; do
        if [ -f "$out/bin/$cmd" ]; then
          wrapProgram $out/bin/$cmd \
            --prefix PATH : ${lib.makeBinPath [ripgrep ffmpeg git nodejs openssh]}
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
