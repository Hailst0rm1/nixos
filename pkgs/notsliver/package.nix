{
  lib,
  python3,
  fetchFromGitHub,
  fetchPypi,
}: let
  python = python3;

  sliver-py = python.pkgs.buildPythonPackage {
    pname = "sliver-py";
    version = "0.0.19";
    format = "wheel";

    src = fetchPypi {
      pname = "sliver_py";
      version = "0.0.19";
      format = "wheel";
      dist = "py3";
      python = "py3";
      hash = "sha256-ihxKhCjSWipdAA0+c/UQvWWRC/u+koc4BhvnnuDqF+A=";
    };

    dependencies = with python.pkgs; [
      grpcio
      grpcio-tools
      mypy-protobuf
    ];

    pythonRelaxDeps = ["mypy-protobuf"];

    pythonImportsCheck = ["sliver"];

    meta = {
      description = "Sliver C2 gRPC client library for Python";
      homepage = "https://github.com/moloch--/sliver-py";
      license = lib.licenses.gpl3Only;
    };
  };
in
  python.pkgs.buildPythonApplication {
    pname = "notsliver";
    version = "1.0.0-unstable-2026-02-27";
    pyproject = true;

    src = fetchFromGitHub {
      owner = "Hailst0rm1";
      repo = "NotSliver";
      rev = "21e9ac4f65902b689acf3c4087c18e589e6d46e5";
      hash = "sha256-k4XeB7cddVYW0SVRi4yzEGZSQOPPhSAHHtunlzgaTRw=";
    };

    # Include templates and static files that setuptools doesn't pick up automatically
    postPatch = ''
      cat >> pyproject.toml <<'EOF'

      [tool.setuptools.package-data]
      "src" = ["web/templates/**/*", "web/static/**/*"]
      EOF
    '';

    build-system = [python.pkgs.setuptools];

    dependencies = with python.pkgs; [
      flask
      flask-cors
      sliver-py
      pyyaml
    ];

    # flask-cors in nixpkgs has broken metadata (reports 0.0.1 instead of actual version)
    pythonRelaxDeps = ["flask-cors"];

    pythonImportsCheck = ["src"];

    meta = {
      description = "Web-based operator tool for Sliver C2 with Flask and HTMX";
      longDescription = ''
        NotSliver is a web-based operator tool for Sliver C2, built with Flask
        and HTMX. It provides a streamlined GUI for managing implants, running
        operations, and collecting loot during penetration testing engagements.

        Intended for authorized penetration testing engagements only.
      '';
      homepage = "https://github.com/Hailst0rm1/NotSliver";
      license = lib.licenses.mit;
      maintainers = [];
      platforms = lib.platforms.linux;
      mainProgram = "notsliver";
    };
  }
