{pkgs}: let
  pname = "ghost";
  version = "5.8.0";
in
  pkgs.stdenv.mkDerivation {
    inherit pname version;
    buildInputs = with pkgs; [nodejs yarn vips];
    ghostCliVersion = "1.21.1";
    builder = ./builder.sh;
  }
