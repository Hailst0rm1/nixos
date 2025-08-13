{
  lib,
  fetchFromGitHub,
  python3Packages,
}:
python3Packages.buildPythonApplication rec {
  pname = "autorecon";
  # from pyproject.toml
  version = "2.0.36";

  src = fetchFromGitHub {
    owner = "Tib3rius";
    repo = "AutoRecon";
    rev = "fd87c99";
    # replace after prefetch (see below)
    hash = "sha256-4yerINhRHINL8oDjF0ES72QrO0DLK6C5Y0wJ913Nozg=";
  };

  # PEP 517 backend: Poetry (poetry-core)
  pyproject = true;
  build-system = [python3Packages.poetry-core];

  propagatedBuildInputs = with python3Packages; [
    platformdirs
    colorama
    impacket
    psutil
    requests
    toml
    unidecode
  ];

  pythonRelaxDeps = ["impacket" "psutil"];

  # smoke-test import is enough; upstream tests need network
  doCheck = false;
  pythonImportsCheck = ["autorecon"];

  meta = with lib; {
    description = "Multi-threaded network recon tool that automates service enumeration";
    homepage = "https://github.com/Tib3rius/AutoRecon";
    license = licenses.gpl3Only;
    platforms = platforms.linux;
    mainProgram = "autorecon";
  };
}
