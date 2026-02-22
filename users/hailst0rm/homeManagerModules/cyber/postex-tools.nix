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
      sha256 = "sha256-XBe/o6/AEV+jT51N0WGMzhCiaUjBfPJfv69y7hMDlTs=";
    };
    phases = ["installPhase"];
    installPhase = ''
      mkdir -p $out
      install -m755 $src $out/Rubeus.exe
    '';
  };

  winpeasExe = pkgs.stdenv.mkDerivation {
    pname = "winpeasExe";
    version = "20260212-43b28429";
    src = pkgs.fetchurl {
      url = "https://github.com/peass-ng/PEASS-ng/releases/download/20260212-43b28429/winPEASany_ofs.exe";
      sha256 = "sha256-MhruHtZhhFIXIFrd+wzQ3BuqAPwn8uXWeGfsL+4exKo=";
    };
    phases = ["installPhase"];
    installPhase = ''
      mkdir -p $out
      install -m755 $src $out/winpeas.exe
    '';
  };

  privescCheck = pkgs.stdenv.mkDerivation {
    pname = "privescCheck";
    version = "2026.01.30-1";
    src = pkgs.fetchurl {
      url = "https://github.com/itm4n/PrivescCheck/releases/latest/download/PrivescCheck.ps1";
      sha256 = "sha256-ZqqoefNqynIt5TMePmwFSnM4EeVyXwxZXl0/iiR8R5g=";
    };
    phases = ["installPhase"];
    installPhase = ''
      mkdir -p $out
      install -m755 $src $out/PrivescCheck.ps1
    '';
  };

  linpeas = pkgs.stdenv.mkDerivation {
    pname = "linpeas";
    version = "20260212-43b28429";
    src = pkgs.fetchurl {
      url = "https://github.com/peass-ng/PEASS-ng/releases/download/20260212-43b28429/linpeas_fat.sh";
      sha256 = "sha256-Ibaj01KFllh6OtdrFwuvbmrbU1DRzZWr3YjUvs4PSLY=";
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

  printSpoofer = pkgs.stdenv.mkDerivation {
    pname = "printSpoofer";
    version = "latest";
    src = pkgs.fetchurl {
      url = "https://github.com/k4sth4/PrintSpoofer/raw/refs/heads/main/PrintSpoofer.exe";
      sha256 = "sha256-nW+Cx1uQz61JB89OuOwe1XshclokJX9ESvRtnEhroMs=";
    };
    phases = ["installPhase"];
    installPhase = ''
      mkdir -p $out
      install -m755 $src $out/PrintSpoofer.exe
    '';
  };

  simpleAspxWebshell = pkgs.stdenv.mkDerivation {
    pname = "simple-aspx-webshell";
    version = "latest";
    src = pkgs.fetchurl {
      name = "aspx-shell.aspx";
      url = "https://raw.githubusercontent.com/xl7dev/WebShell/refs/heads/master/Aspx/ASPX%20Shell.aspx";
      sha256 = "sha256-rxwAaWJD+LBipT2tn7i3c/ofA5VjH/5sfezELEfu3uc=";
    };
    phases = ["installPhase"];
    installPhase = ''
      mkdir -p $out
      install -m755 $src $out/simple-aspx-webshell.aspx
    '';
  };

  adPEAS-Light = pkgs.stdenv.mkDerivation {
    # adPEAS-Light (all modules without sharphound)
    pname = "adPEAS-Light";
    version = "v0.8.28";
    src = pkgs.fetchurl {
      url = "https://github.com/61106960/adPEAS/raw/refs/heads/main/adPEAS-Light.ps1";
      sha256 = "sha256-p/hPvSmQLIZ7xRWZlhtrdtQd4vIG4JCaDzTLw8ZTVYc=";
    };
    phases = ["installPhase"];
    installPhase = ''
      mkdir -p $out
      install -m755 $src $out/adPEAS-Light.ps1
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
        cp -f ${adPEAS-Light}/adPEAS-Light.ps1 "${config.home.homeDirectory}/cyber/postex-tools/adPEAS-Light.ps1"
        cp -f ${printSpoofer}/PrintSpoofer.exe "${config.home.homeDirectory}/cyber/postex-tools/PrintSpoofer.exe"
        cp -f ${builtins.toPath ./files/Notnop.ps1} "${config.home.homeDirectory}/cyber/postex-tools/Notnop.ps1"
        cp -f ${builtins.toPath ./files/escalator.sh} "${config.home.homeDirectory}/cyber/postex-tools/escalator"
        cp -f ${builtins.toPath ./files/Disable-AVProduct.min.ps1} "${config.home.homeDirectory}/cyber/postex-tools/Disable-AVProduct.min.ps1"
        cp -f ${builtins.toPath ./files/Disable-AVProduct.ps1} "${config.home.homeDirectory}/cyber/postex-tools/Disable-AVProduct.ps1"
        cp -f ${builtins.toPath ./files/Get-AppLockerRules.ps1} "${config.home.homeDirectory}/cyber/postex-tools/Get-AppLockerRules.ps1"

        cp -f ${builtins.toPath ./files/php-webshell.php} "${config.home.homeDirectory}/cyber/postex-tools/payloads/php-webshell.php"
        cp -f ${simpleAspxWebshell}/simple-aspx-webshell.aspx "${config.home.homeDirectory}/cyber/postex-tools/payloads/simple-aspx-webshell.aspx"
      '';

      packages = with pkgs-unstable; [
        bloodhound
        mimikatz
      ];
    };
  };
}
