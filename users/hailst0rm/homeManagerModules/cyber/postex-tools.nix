{
  inputs,
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}: let
  # Postex-Tools
  rubeus = pkgs.stdenv.mkDerivation {
    pname = "rubeus";
    version = "4.8.1-compiled";
    src = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/r3motecontrol/Ghostpack-CompiledBinaries/master/dotnet%20v4.8.1%20compiled%20binaries/Rubeus.exe";
      sha256 = "sha256-QKS15U/szlLJ2O9bL6OXOj3XSMW87de94RVKpKk2wuE=";
    };
    phases = ["installPhase"];
    installPhase = ''
      mkdir -p $out
      install -m755 $src $out/Rubeus.exe
    '';
  };

  winpeasExe = pkgs.stdenv.mkDerivation {
    pname = "winpeasExe";
    version = "20250801-03e73bf3";
    src = pkgs.fetchurl {
      url = "https://github.com/peass-ng/PEASS-ng/releases/download/20250801-03e73bf3/winPEASany_ofs.exe";
      sha256 = "sha256-lR9CLMQd2JrjCUSidJ1YW1CiGJlZ8o8bUivjODyusFE=";
    };
    phases = ["installPhase"];
    installPhase = ''
      mkdir -p $out
      install -m755 $src $out/winpeas.exe
    '';
  };

  privescCheck = pkgs.stdenv.mkDerivation {
    pname = "privescCheck";
    version = "2025-08-17_f0d437d";
    src = pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/itm4n/PrivescCheck/refs/heads/master/PrivescCheck.ps1";
      sha256 = "sha256-hJnTztTpYp57CFebjL07GsYnLeetlWnz2SSheG0wOd4=";
    };
    phases = ["installPhase"];
    installPhase = ''
      mkdir -p $out
      install -m755 $src $out/PrivescCheck.ps1
    '';
  };

  linpeas = pkgs.stdenv.mkDerivation {
    pname = "linpeas";
    version = "20250801-03e73bf3";
    src = pkgs.fetchurl {
      url = "https://github.com/peass-ng/PEASS-ng/releases/download/20250801-03e73bf3/linpeas_fat.sh";
      sha256 = "sha256-5CMVpLqSZtOjysfWLYbM8TphGYDbjUv2lWKpreTiEFY=";
    };
    phases = ["installPhase"];
    installPhase = ''
      mkdir -p $out
      install -m755 $src $out/linpeas
    '';
  };

  sigmaPotato = pkgs.stdenv.mkDerivation {
    pname = "sigmaPotato";
    version = "v1.2.6";
    src = pkgs.fetchurl {
      url = "https://github.com/tylerdotrar/SigmaPotato/releases/download/v1.2.6/SigmaPotato.exe";
      sha256 = "sha256-7Gimv38QSoFb0h4n5zqN+4r8soLUmXvr6ezNbIkllQY=";
    };
    phases = ["installPhase"];
    installPhase = ''
      mkdir -p $out
      install -m755 $src $out/SigmaPotato.exe
    '';
  };
in {
  config = lib.mkIf config.cyber.redTools.enable {
    home = {
      # Allows me to bypass read-only fs
      activation.copyTools = lib.hm.dag.entryAfter ["writeBoundary"] ''
        mkdir -p "${config.home.homeDirectory}/cyber/postex-tools"

        # cp -f ${pkgs-unstable.bloodhound}/lib/BloodHound/resources/app/Collectors/SharpHound.ps1 "${config.home.homeDirectory}/cyber/postex-tools/SharpHound.ps1"
        cp -f ${rubeus}/Rubeus.exe "${config.home.homeDirectory}/cyber/postex-tools/Rubeus.exe"
        cp -f ${pkgs-unstable.mimikatz}/share/windows/mimikatz/x64/mimikatz.exe "${config.home.homeDirectory}/cyber/postex-tools/mimikatz.exe"
        cp -f ${winpeasExe}/winpeas.exe "${config.home.homeDirectory}/cyber/postex-tools/winpeas.exe"
        cp -f ${linpeas}/linpeas "${config.home.homeDirectory}/cyber/postex-tools/linpeas"
        cp -f ${privescCheck}/PrivescCheck.ps1 "${config.home.homeDirectory}/cyber/postex-tools/PrivescCheck.ps1"
        cp -f ${sigmaPotato}/SigmaPotato.exe "${config.home.homeDirectory}/cyber/postex-tools/SigmaPotato.exe"
        cp -f ${builtins.toPath ./files/Notnop.ps1} "${config.home.homeDirectory}/cyber/postex-tools/Notnop.ps1"
        cp -f ${builtins.toPath ./files/escalator.sh} "${config.home.homeDirectory}/cyber/postex-tools/escalator"

      '';

      packages = with pkgs-unstable; [
        bloodhound
        mimikatz
      ];
    };
  };
}
