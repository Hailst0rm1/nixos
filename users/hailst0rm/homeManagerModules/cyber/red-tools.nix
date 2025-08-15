{
  inputs,
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}: let
  # Custom packages
  nixosDir = inputs.self;
  thc-hydra = pkgs-unstable.callPackage "${nixosDir}/pkgs/thc-hydra/package.nix" {};
  autorecon = pkgs-unstable.callPackage "${nixosDir}/pkgs/autorecon/package.nix" {};
  # ipcrawler = pkgs-unstable.callPackage "${nixosDir}/pkgs/ipcrawler/package.nix" {};
  ipmap = builtins.readFile ./files/ipmap.sh;

  ligolo-mp = pkgs.stdenv.mkDerivation {
    pname = "ligolo-mp";
    version = "2.1.0";

    src = pkgs.fetchurl {
      url = "https://github.com/ttpreport/ligolo-mp/releases/download/v2.1.0/ligolo-mp_linux_amd64";
      sha256 = "sha256-W4k2ExJk5P4pjNvvmBilrL++3Haz9LMxbWKRWEsnYaI=";
    };

    phases = ["installPhase"];
    installPhase = ''
      mkdir -p $out/bin
      install -m755 $src $out/bin/ligolo-mp
    '';
  };

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
in {
  # options.redTools.enable = lib.mkEnableOption "Enable Red Tooling";

  config = lib.mkIf config.cyber.redTools.enable {
    home = {
      file = {
        "cyber/wordlists".source = "${pkgs-unstable.wordlists}/share/wordlists";
        "cyber/hashcat-rules".source = "${pkgs-unstable.hashcat}/share/doc/hashcat/rules";
        "cyber/john-rules/john.conf".source = "${pkgs-unstable.john}/etc/john/john.conf";
        "cyber/metasploit/win-revtcp-listener.rc".source = ./files/win-revtcp-listener.rc;
        "cyber/AutoRecon/config.toml".source = ./files/autorecon-config.toml;
        # "cyber/postex-tools/SharpHound.ps1".source = "${pkgs-unstable.bloodhound}/resources/app/Collectors/SharpHound.ps1";
        # "cyber/ligolo/config.yaml".source = ./files/ligolo-config.yaml;
      };

      # Allows me to bypass read-only fs
      activation.copyTools = lib.hm.dag.entryAfter ["writeBoundary"] ''
        mkdir -p "${config.home.homeDirectory}/cyber/postex-tools"

        # mkdir -p "${config.home.homeDirectory}/cyber/ligolo"
        # cp -f ${builtins.toPath ./files/ligolo-config.yaml} "${config.home.homeDirectory}/ligolo.yaml"
        # chmod 666 "${config.home.homeDirectory}/ligolo.yaml"

        cp -f ${pkgs-unstable.bloodhound}/lib/BloodHound/resources/app/Collectors/SharpHound.ps1 "${config.home.homeDirectory}/cyber/postex-tools/SharpHound.ps1"
        cp -f ${rubeus}/Rubeus.exe "${config.home.homeDirectory}/cyber/postex-tools/Rubeus.exe"

      '';

      sessionVariables = {
      };
      packages = with pkgs-unstable; [
        # === Testing corner ===
        # wireshark
        wineWowPackages.wayland
        ligolo-mp

        # === Reconnaissance ===

        # Passive
        whois
        gitleaks # Find creds in git-applications
        exiftool # Information via metadata on targets public resources
        subfinder # Subdirectory finder
        gau # Get-all-Urls - get known urls
        theharvester # Emails, names, IPs, subdomains
        waymore # Wayback explorer query and download
        trufflehog # Find exposed credentials

        # Active
        autorecon # Automatic recon
        enum4linux-ng # ^Dependency: Enum samba & Windows
        redis # ^Dependency
        nmap
        nmap-formatter
        rustscan # Fast nmap
        dnsrecon # DNS recon
        nbtscan # NetBIOS scan (port 139)
        net-snmp # Includes: snmpwalk (port UDP/161)
        onesixtyone # SNMP Scanner (port UDP/161)
        exploitdb # Searchsploit, searchable vulnerability DB
        libxml2 # ^Dependency
        smbmap # SMB Scanner (tcp/445)
        nuclei # Vulnerability scanner

        # Web
        # ipcrawler # Identify best wordlist
        whatweb # Web scanner (meta)
        nikto # Another web scanner
        gobuster # Directory busting
        ffuf # Fuzzing
        feroxbuster # Ffuf alternative
        # burpsuite # Webapp testing
        caido # Burp alternative in rust
        chromium # For Caido
        sqlmap # SQL Injection
        wpscan # Wordpress scanner
        httpx # Check which hosts are alive, and fingerprint them
        katana # Web crawler
        sslscan # Tests SSL

        # === Resource Development ===
        pkgsCross.mingwW64.buildPackages.gcc

        # === Initial Access ===
        metasploit
        ruby # Dependency
        postgresql_18 # Dependency for MSFDB
        swaks # SMTP Swiss Army Knife

        # === Execution ===
        python313Packages.wsgidav # Used to host WebDAV for hosting of payloads

        # === Lateral Movement ===
        evil-winrm # WinRM shell for hacking/pentesting
        (pkgs.netexec)
        ligolo-ng #  Tunneling/pivoting tool that uses a TUN interface

        # === Credential Access ===
        thc-hydra # Brute force
        hashcat # GPU cracker
        hashcat-utils
        john # CPU cracker
        hashid # Identify hash type (-m for hashcat mode value)
        python312Packages.impacket # ntmlrelayx.py: Relays ntml requests
        mimikatz
        (pkgs.responder) # (OVERLAY) Rogue authentication server to obtain hashes

        # === Discovery ===
        bloodhound

        # === Command & Control (C2) ===
        #

        # === Cloud ===
        awscli2
        pacu # AWS Exploitation framework

        # === Wordlists ===
        cewl # Wordlist generator based on website
        crunch # Easy wordlist generator
        username-anarchy # Username generator
        wordlists # Note: This includes seclists
        # cd $(wordlists_path) # Go to wordlists
        # <command> $(wordlists_path)/rockyou.txt # Use wordlist
        # wordlists # Displays tree of all lists (can be used with pipe grep)

        # === Misc ===
        (writeShellScriptBin "cyberchef" ''          # For encoding/encryption etc
          ${config.browser} "${cyberchef}/share/cyberchef/index.html"
        '')
        (writeShellScriptBin "ipmap" ipmap) # Map ip to hostname
        go # Required by ligolo-mp
      ];
    };
  };
}
