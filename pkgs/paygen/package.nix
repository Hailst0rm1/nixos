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
    sha256 = "sha256-GX/RunobhobeSNl/JdBHyZoXkkksKKI/7Uf89J+bVaI=";
  };

  propagatedBuildInputs = with python3Packages; [
    textual
    pyyaml
    jinja2
    pycryptodome
    rich
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

    # Create wrapper script that includes all Python dependencies
    makeWrapper ${python3Packages.python.interpreter} $out/bin/paygen \
      --prefix PYTHONPATH : "$out/lib/paygen:$PYTHONPATH" \
      --add-flags "-m src.main"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Menu-driven TUI tool for payload generation with YAML-based recipes";
    homepage = "https://github.com/Hailst0rm1/paygen";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = [];
  };
}
