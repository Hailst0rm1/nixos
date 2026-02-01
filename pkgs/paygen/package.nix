{
  lib,
  python3Packages,
  fetchFromGitHub,
  makeWrapper,
}:
python3Packages.buildPythonApplication rec {
  pname = "paygen";
  version = "2.0.0";
  format = "other";

  src = fetchFromGitHub {
    owner = "Hailst0rm1";
    repo = "paygen";
    rev = "main"; # You can pin to a specific commit/tag later
    sha256 = "sha256-QQPcNu4q3MEJRMuKB59t5zZX6x4KnNIwvletp/tYBRw=";
  };

  propagatedBuildInputs = with python3Packages; [
    pyyaml
    jinja2
    pycryptodome
    rich
    flask
    flask-cors
  ];

  nativeBuildInputs = with python3Packages; [
    pytest
    makeWrapper
  ];

  # Don't run tests during build (they require the full environment)
  doCheck = false;

  installPhase = ''
    runHook preInstall

    # Create installation directories
    mkdir -p $out/bin
    mkdir -p $out/lib/paygen

    # Copy source files
    cp -r src $out/lib/paygen/
    cp -r recipes $out/lib/paygen/
    cp -r preprocessors $out/lib/paygen/
    cp -r templates $out/lib/paygen/

    # Create wrapper script for web interface
    makeWrapper ${python3Packages.python.interpreter} $out/bin/paygen \
      --prefix PYTHONPATH : "$out/lib/paygen:$PYTHONPATH" \
      --add-flags "-m src.main"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Web-based framework for payload generation with YAML-based recipes";
    homepage = "https://github.com/Hailst0rm1/paygen";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = [];
  };
}
