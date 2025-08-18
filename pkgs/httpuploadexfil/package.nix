{
  lib,
  fetchFromGitHub,
  buildGoModule,
}:
buildGoModule rec {
  pname = "httpuploadexfil";
  version = "2025-08-16";

  src = fetchFromGitHub {
    owner = "IngoKl";
    repo = "HTTPUploadExfil";
    rev = "main"; # or a specific commit
    sha256 = "sha256-C5itJYoKBQe3BISlMk8dILrBu8ijXT97M1CanySJe18="; # run once to get the real hash
  };

  vendorHash = null; # let Nix fetch the modules upstream

  meta = with lib; {
    description = "Simple HTTP server for exfiltrating files/data (CTFs etc.)";
    homepage = "https://github.com/IngoKl/HTTPUploadExfil";
    license = licenses.mit;
    platforms = platforms.all;
  };
}
