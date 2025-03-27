{
  config,
  lib,
  pkgs-unstable,
  ...
}: {
  options.redTools.enable = lib.mkEnableOption "Enable Red Tooling";

  config = lib.mkIf config.redTools.enable (with pkgs-unstable; {
    home.packages = [

      # === Testing corner ===

      # === Reconnaissance ===
     
      # Passive
      whois
      gitleaks # Find creds in git-applications
      
      # Active
      nmap
      nmap-formatter
      rustscan # Fast nmap
      dnsrecon # DNS recon
      nbtscan # NetBIOS scan (port 139)
      net-snmp # Includes: snmpwalk (port UDP/161)

      # Web
      subfinder # Subdirectory finder
      gobuster # Directory busting
      

      # === Resource Development ===


      # === Initial Access ===

      # === Wordlists ===
      wordlists # Note: This includes seclists
                # cd $(wordlists_path) # Go to wordlists
                # <command> $(wordlists_path)/rockyou.txt # Use wordlist
                # wordlists # Displays tree of all lists (can be used with pipe grep)

    ];
  });
}

