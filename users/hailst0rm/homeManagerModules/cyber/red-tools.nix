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
in {
  # options.redTools.enable = lib.mkEnableOption "Enable Red Tooling";

  config = lib.mkIf config.cyber.redTools.enable {
    home = {
      file = {
        "cyber/wordlists".source = "${pkgs-unstable.wordlists}/share/wordlists";
        "cyber/hashcat-rules".source = "${pkgs-unstable.hashcat}/share/doc/hashcat/rules";
        "cyber/john-rules/john.conf".source = "${pkgs-unstable.john}/etc/john/john.conf";
        "cyber/metasploit/win-revtcp-listener.rc".source = ./files/win-revtcp-listener.rc;
        # "cyber/postex-tools/SharpHound.ps1".source = "${pkgs-unstable.bloodhound}/resources/app/Collectors/SharpHound.ps1";
        # "cyber/ligolo/config.yaml".source = ./files/ligolo-config.yaml;
      };

      # Allows me to bypass read-only fs
      activation.copyTools = lib.hm.dag.entryAfter ["writeBoundary"] ''
        mkdir -p "${config.home.homeDirectory}/cyber/ligolo"
        mkdir -p "${config.home.homeDirectory}/cyber/postex-tools"

        cp -f ${builtins.toPath ./files/ligolo-config.yaml} "${config.home.homeDirectory}/ligolo.yaml"
        cp -f ${pkgs-unstable.bloodhound}/lib/BloodHound/resources/app/Collectors/SharpHound.ps1 "${config.home.homeDirectory}/cyber/postex-tools/SharpHound.ps1"

        chmod 666 "${config.home.homeDirectory}/ligolo.yaml"
      '';

      sessionVariables = {
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
        nmap
        nmap-formatter
        rustscan # Fast nmap
        dnsrecon # DNS recon
        nbtscan # NetBIOS scan (port 139)
        net-snmp # Includes: snmpwalk (port UDP/161)
        exploitdb # Searchsploit, searchable vulnerability DB
        libxml2 # ^Dependency
        nuclei # Vulnerability scanner

        # Web
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

        # === Resource Development ===
        pkgsCross.mingwW64.buildPackages.gcc

        # === Initial Access ===
        metasploit
        ruby # Dependency
        postgresql_18 # Dependency for MSFDB

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

        # === Wordlists ===
        cewl # Wordlist generator based on website
        crunch # Easy wordlist generator
        wordlists # Note: This includes seclists
        # cd $(wordlists_path) # Go to wordlists
        # <command> $(wordlists_path)/rockyou.txt # Use wordlist
        # wordlists # Displays tree of all lists (can be used with pipe grep)

        # === Misc ===
        (writeShellScriptBin "cyberchef" ''          # For encoding/encryption etc
          ${config.browser} "${cyberchef}/share/cyberchef/index.html"
        '')
      ];
    };
  };
}
