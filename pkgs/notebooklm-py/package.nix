{
  lib,
  python3,
  fetchFromGitHub,
  makeWrapper,
  playwright-driver,
}:
python3.pkgs.buildPythonApplication {
  pname = "notebooklm-py";
  version = "0.8.2";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "teng-lin";
    repo = "notebooklm-py";
    rev = "v0.8.2";
    hash = "sha256-FgZFd8t6e2pRcd0ilfxgw2+bioyCVgOhF/zQ4whjEEU=";
  };

  nativeBuildInputs = [makeWrapper];

  build-system = with python3.pkgs; [
    hatchling
    hatch-fancy-pypi-readme
  ];

  dependencies = with python3.pkgs; [
    httpx
    click
    rich
    filelock
    playwright
  ];

  postFixup = ''
    wrapProgram $out/bin/notebooklm \
      --set PLAYWRIGHT_BROWSERS_PATH "${playwright-driver.browsers}"
  '';

  # Tests require network access and Google auth
  doCheck = false;

  meta = with lib; {
    description = "Unofficial Python library for automating Google NotebookLM";
    homepage = "https://github.com/teng-lin/notebooklm-py";
    license = licenses.mit;
    maintainers = [];
    platforms = platforms.linux;
    mainProgram = "notebooklm";
  };
}
