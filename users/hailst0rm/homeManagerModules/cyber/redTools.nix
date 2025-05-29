{
  config,
  lib,
  pkgs-unstable,
  ...
}: {
  # options.redTools.enable = lib.mkEnableOption "Enable Red Tooling";

  config = lib.mkIf config.cyber.redTools.enable (with pkgs-unstable; {
    home = {
      file = {
        "wordlists".source = "${pkgs-unstable.wordlists}/share/wordlists";
      };
      sessionVariables = {
      };
      packages = [
        # === Testing corner ===
        # wireshark
        pkgs.wineWowPackages.wayland

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

        # === Execution ===
        python313Packages.wsgidav # Used to host WebDAV for hosting of payloads

        # === Lateral Movement ===
        #samba4Full # Interact with SMB shares (smbclient) (CEPH TAKES 10 YEARS TO BUILD)

        # === Credential Access ===
        # (thc-hydra.overrideAttrs (old: {
        #   buildInputs = old.buildInputs ++ [ pkgs.freerdp ];
        # }))
        # (thc-hydra.overrideAttrs (old: {
        #   buildInputs = old.buildInputs ++ [freerdp3];
        # }))
        (thc-hydra.overrideAttrs (old: {
          pname = "thc-hydra";
          version = "unstable-2025-05-27"; # Update to current date or appropriate version label

          src = fetchFromGitHub {
            owner = "vanhauser-thc";
            repo = "thc-hydra";
            rev = "e4367b2f1326a43f1618b5eee59aaec8ade1442b";
            sha256 = "sha256-2EwULcI2sfMQzMN2Cxsd4NlOvu5s/J3gvKQZr10jPj0="; # Replace with actual hash
          };

          buildInputs = old.buildInputs ++ [freerdp3];
        }))
        freerdp

        # === Wordlists ===
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
  });
}
