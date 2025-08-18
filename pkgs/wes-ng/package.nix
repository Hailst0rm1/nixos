{
  lib,
  fetchFromGitHub,
  python3Packages,
}:
python3Packages.buildPythonApplication rec {
  pname = "wes-ng";
  version = "1.0.3";

  # Fetch from GitHub
  src = fetchFromGitHub {
    owner = "bitsadmin";
    repo = "wesng";
    rev = "ae9079a";
    sha256 = "sha256-AqVKz1uOZakUhd0zG7c9TzzErZS16QEB7R8jQv6KMWc="; # Replace with real hash using nix-prefetch
  };

  pyproject = true;

  nativeBuildInputs = [
    python3Packages.setuptools
    python3Packages.wheel
  ];
  propagatedBuildInputs = with python3Packages; [
    chardet
    termcolor
  ];

  doCheck = false; # No tests provided upstream

  # Install script entrypoint
  meta = with lib; {
    description = "WES-NG is a tool based on Windows systeminfo output to list OS vulnerabilities and exploits.";
    homepage = "https://github.com/bitsadmin/wesng";
    license = licenses.bsd2; # matches BSD License in setup.py
    maintainers = with maintainers; [];
    platforms = platforms.all;
  };
}
