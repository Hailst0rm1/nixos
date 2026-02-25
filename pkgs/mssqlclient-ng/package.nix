{
  lib,
  python3,
  fetchFromGitHub,
}:
python3.pkgs.buildPythonApplication {
  pname = "mssqlclient-ng";
  version = "0.9.1-unstable-2025-12-22";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "n3rada";
    repo = "mssqlclient-ng";
    rev = "8c9962e1125957c5f09cffd15213ad87dedb9d95";
    hash = "sha256-ePUpBxBzesB+Knt6yJGGHcpjx7dSHY4QreZ2cH9uPUA=";
  };

  postPatch = ''
    substituteInPlace pyproject.toml \
      --replace-fail " @ git+https://github.com/fortra/impacket.git@master" ""
  '';

  build-system = [python3.pkgs.uv-build];

  dependencies = with python3.pkgs; [
    loguru
    prompt-toolkit
    pygments
    impacket
  ];

  pythonImportsCheck = ["mssqlclient_ng"];

  meta = {
    description = "Enhanced version of impacket's mssqlclient.py for MSSQL interaction";
    longDescription = ''
      mssqlclient-ng lets you interact with Microsoft SQL Server instances and
      their linked instances, impersonating any account encountered along the way,
      without requiring complex T-SQL queries.

      Intended for authorized penetration testing engagements only.
    '';
    homepage = "https://github.com/n3rada/mssqlclient-ng";
    license = lib.licenses.gpl3Plus;
    maintainers = [];
    platforms = lib.platforms.linux;
    mainProgram = "mssqlclient-ng";
  };
}
