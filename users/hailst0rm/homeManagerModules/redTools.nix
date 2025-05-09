{
  config,
  lib,
  pkgs-unstable,
  ...
}: {
  # options.redTools.enable = lib.mkEnableOption "Enable Red Tooling";

  config = lib.mkIf config.redTools.enable (with pkgs-unstable; {
    home = {
      sessionVariables = {
      };
      packages = [

        # === Testing corner ===

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


        # === Initial Access ===
        metasploit

        # === Execution ===
        python313Packages.wsgidav # Used to host WebDAV for hosting of payloads

        # === Lateral Movement ===
        samba4Full # Interact with SMB shares (smbclient)

        # === Wordlists ===
        wordlists # Note: This includes seclists
                  # cd $(wordlists_path) # Go to wordlists
                  # <command> $(wordlists_path)/rockyou.txt # Use wordlist
                  # wordlists # Displays tree of all lists (can be used with pipe grep)
              
        # === Misc ===
        (writeShellScriptBin "cyberchef" '' # For encoding/encryption etc
          ${config.browser} "${cyberchef}/share/cyberchef/index.html"
        '')
      ];
    };
  });
}

