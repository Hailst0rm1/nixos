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
    version = "2025-09-15";
    src = pkgs.fetchurl {
      url = "https://github.com/Syslifters/offsec-tools/raw/refs/heads/main/bin/Rubeus.exe";
      sha256 = "sha256-rq87GQoc8mbAejvuyokd8XJLryKllnlqP/3b71sCH2Q=";
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
    version = "2025-09-03_2fdcae8";
    src = pkgs.fetchurl {
      url = "https://github.com/itm4n/PrivescCheck/releases/latest/download/PrivescCheck.ps1";
      sha256 = "sha256-vfRwjvAL32XRcetqTIMN4IuLQvdRClMyVDzEAnxJZjs=";
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

  pspy = pkgs.stdenv.mkDerivation {
    pname = "pspy";
    version = "latest";
    src = pkgs.fetchurl {
      url = "https://github.com/DominicBreuker/pspy/releases/download/v1.2.1/pspy64";
      sha256 = "sha256-yT8ppcwTR725DhShJCTmRpyM/qmiC4ALwkl1XwBDo7s=";
    };
    phases = ["installPhase"];
    installPhase = ''
      mkdir -p $out
      install -m755 $src $out/pspy
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
        mkdir -p "${config.home.homeDirectory}/cyber/postex-tools/payloads"
        mkdir -p "${config.home.homeDirectory}/cyber/wordlists-custom"

        cp -f ${builtins.toPath ./files/common-ssh-key-names.txt} "${config.home.homeDirectory}/cyber/wordlists-custom/common-ssh-key-names.txt"
        # cp -f ${pkgs-unstable.bloodhound}/lib/BloodHound/resources/app/Collectors/SharpHound.ps1 "${config.home.homeDirectory}/cyber/postex-tools/SharpHound.ps1"
        cp -f ${rubeus}/Rubeus.exe "${config.home.homeDirectory}/cyber/postex-tools/Rubeus.exe"
        cp -f ${pkgs-unstable.mimikatz}/share/windows/mimikatz/x64/mimikatz.exe "${config.home.homeDirectory}/cyber/postex-tools/mimikatz.exe"
        cp -f ${winpeasExe}/winpeas.exe "${config.home.homeDirectory}/cyber/postex-tools/winpeas.exe"
        cp -f ${linpeas}/linpeas "${config.home.homeDirectory}/cyber/postex-tools/linpeas"
        cp -f ${pspy}/pspy "${config.home.homeDirectory}/cyber/postex-tools/pspy"
        cp -f ${privescCheck}/PrivescCheck.ps1 "${config.home.homeDirectory}/cyber/postex-tools/PrivescCheck.ps1"
        cp -f ${sigmaPotato}/SigmaPotato.exe "${config.home.homeDirectory}/cyber/postex-tools/SigmaPotato.exe"
        cp -f ${builtins.toPath ./files/Notnop.ps1} "${config.home.homeDirectory}/cyber/postex-tools/Notnop.ps1"
        cp -f ${builtins.toPath ./files/escalator.sh} "${config.home.homeDirectory}/cyber/postex-tools/escalator"
        cp -f ${builtins.toPath ./files/Scanner.ps1} "${config.home.homeDirectory}/cyber/postex-tools/Scanner.ps1"

        cp -f ${builtins.toPath ./files/php-webshell.php} "${config.home.homeDirectory}/cyber/postex-tools/payloads/php-webshell.php"
      '';

      packages = with pkgs-unstable; [
        bloodhound
        mimikatz
      ];
    };
  };
}
