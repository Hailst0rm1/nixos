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
  httpuploadexfil = pkgs-unstable.callPackage "${nixosDir}/pkgs/httpuploadexfil/package.nix" {};
  wes-ng = pkgs-unstable.callPackage "${nixosDir}/pkgs/wes-ng/package.nix" {};
  # ipcrawler = pkgs-unstable.callPackage "${nixosDir}/pkgs/ipcrawler/package.nix" {};
  ipmap = builtins.readFile ./files/ipmap.sh;
  listeners = builtins.readFile ./files/listeners.sh;
  atm = builtins.readFile ./files/atm.sh;
  var = builtins.readFile ./files/var.sh;
  portspoof = builtins.readFile ./files/portspoof.sh;
  portmux = builtins.readFile ./files/portmux.sh;

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
in {
  # options.redTools.enable = lib.mkEnableOption "Enable Red Tooling";

  config = lib.mkIf config.cyber.redTools.enable {
    home = {
      file = {
        "cyber/wordlists".source = "${pkgs-unstable.wordlists}/share/wordlists";
        "cyber/hashcat-rules".source = "${pkgs-unstable.hashcat}/share/doc/hashcat/rules";
        "cyber/john-rules/john.conf".source = "${pkgs-unstable.john}/etc/john/john.conf";
        "cyber/metasploit/win-revtcp-listener.rc".source = ./files/win-revtcp-listener.rc;
        "cyber/metasploit/lin-revtcp-listener.rc".source = ./files/lin-revtcp-listener.rc;
        "cyber/AutoRecon/config.toml".source = ./files/autorecon-config.toml;
        ".nxc/nxc.conf".source = ./files/nxc.conf;
        "cyber/AutoRecon/Plugins" = {
          source = ./files/AutoRecon-Plugins;
          recursive = true;
        };
        # "cyber/postex-tools/SharpHound.ps1".source = "${pkgs-unstable.bloodhound}/resources/app/Collectors/SharpHound.ps1";
        # "cyber/ligolo/config.yaml".source = ./files/ligolo-config.yaml;
      };

      packages = with pkgs-unstable; [
        # === Testing corner ===
        # wireshark
        wineWowPackages.wayland

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
        penelope # Shell Handler

        # === Execution ===
        python313Packages.wsgidav # Used to host WebDAV for hosting of payloads

        # === Privilege Escalation ===
        wes-ng # Windows-exploit-suggester
        linux-exploit-suggester

        # === Lateral Movement ===
        evil-winrm # WinRM shell for hacking/pentesting
        netexec
        smbclient-ng # A GOOD smbclient
        # ligolo-ng # Tunneling/pivoting tool that uses a TUN interface
        ligolo-mp # Tunneling/pivoting tool that uses a TUN interface (multiplayer + tui)
        (pkgs.garble) # Ligolo-mp dependency: Obfuscation

        # === Credential Access ===
        (writeShellScriptBin "atm" atm) # CUSTOM: netexec credential gathering automation
        thc-hydra # Brute force
        hashcat # GPU cracker
        hashcat-utils
        john # CPU cracker
        hashid # Identify hash type (-m for hashcat mode value)
        python312Packages.impacket # ntmlrelayx.py: Relays ntml requests
        (pkgs.responder) # (OVERLAY) Rogue authentication server to obtain hashes

        # === Discovery ===
        bloodhound
        bloodhound-py # Bloodhound ingestor (remote SharpHound)

        # === Command & Control (C2) ===
        #

        # === Exfiltration ===
        httpuploadexfil # Like Python server, but upload

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
        (writeShellScriptBin "listeners" listeners) # Start web/msf/exfil/routing servers
        (writeShellScriptBin "var" var) # Easily modify variables
        (writeShellScriptBin "portspoof" portspoof) # Spoof all ports to show as open
        (writeShellScriptBin "portmux" portmux) # Manage ports for services
        go # Required by ligolo-mp
        iptables # Modern iptables (nftables backend) - required by portspoof/mux
      ];
    };
  };
}
