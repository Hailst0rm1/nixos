{
  inputs,
  config,
  hostname,
  lib,
  ...
}: {
  imports =
    [
      # Secrets
      inputs.sops-nix.nixosModules.sops

      # Recursively imports all nixosModules
    ]
    ++ lib.filter
    (n: lib.strings.hasSuffix ".nix" n)
    (lib.filesystem.listFilesRecursive ../nixosModules);

  # variables.nix
  username = lib.mkDefault "hailst0rm";
  hostname = hostname;
  systemArch = lib.mkDefault "x86_64-linux";
  laptop = lib.mkDefault false;
  removableMedia = lib.mkDefault false;
  myLocation = lib.mkDefault "Stockholm";

  # Red Teaming config
  cyber.redTools.enable = lib.mkDefault false;

  # desktop/default.nix
  # Gnome is default
  desktopEnvironment.name = lib.mkDefault "hyprland";

  # Display manager are currently built in the other desktops beside hyprland
  desktopEnvironment.displayManager = {
    enable = lib.mkDefault true;
    name = lib.mkDefault "sddm";
  };

  # graphic
  graphicDriver.intel.enable = lib.mkDefault false;
  graphicDriver.nvidia = {
    enable = lib.mkDefault false;
    type = lib.mkDefault "default";
  };

  security = {
    sops.enable = lib.mkDefault true;
    firewall.enable = lib.mkDefault true;
    dnscrypt.enable = lib.mkDefault false;
    completePolkit.enable = lib.mkDefault false;
    yubikey.enable = lib.mkDefault true;
  };

  # Bluetooth
  hardware.bluetooth.enable = lib.mkDefault true;
  hardware.bluetooth.powerOnBoot = lib.mkDefault false;

  system = {
    kernel = lib.mkDefault "zen";
    bootloader = lib.mkDefault "grub";
    keyboard.colemak-se = lib.mkDefault true;
    theme = {
      enable = lib.mkDefault true;
      name = lib.mkDefault "catppuccin-mocha";
    };
    automatic = {
      upgrade = lib.mkDefault false;
      cleanup = lib.mkDefault true;
    };
  };

  virtualisation = {
    host = {
      vmware = lib.mkDefault false; # Broken?
      virtualbox = lib.mkDefault true;
      qemu = lib.mkDefault false;
    };
    guest = {
      vmware = lib.mkDefault false;
      qemu = lib.mkDefault false;
    };
  };

  # Hosted / Running services (nixosModules/services)
  services = {
    domain = lib.mkDefault "pontonsecurity.com";
    cloudflare = {
      enable = lib.mkDefault false;
      deviceType = lib.mkDefault "client";
    };
    gitlab.serverIp = lib.mkDefault "100.84.181.70";
    podman.enable = lib.mkDefault false;
    openssh.enable = lib.mkDefault false;
    mattermost.enable = lib.mkDefault false;
    ollama.enable = lib.mkDefault false;
    open-webui.enable = lib.mkDefault false; # UI for local AI
    tailscaleAutoconnect = {
      enable = lib.mkDefault true;
      authkeyFile = lib.mkDefault config.sops.secrets."services/tailscale/auth.key".path; # Needs updating every 90 days (okt 16)
      advertiseExitNode = lib.mkDefault false;
      loginServer = lib.mkDefault "https://login.tailscale.com";
      exitNode = lib.mkDefault "100.84.181.70";
      # exitNode = lib.mkDefault "nix-server";
      exitNodeAllowLanAccess = lib.mkDefault true;
    };
  };

  # Allow unfree software
  nixpkgs.config.allowUnfree = lib.mkDefault true;

  # Set your time zone.
  time.timeZone = lib.mkDefault "Europe/Stockholm";

  # Select internationalisation properties.
  i18n.defaultLocale = lib.mkDefault "en_GB.UTF-8";

  # Define a user account.
  users = {
    mutableUsers = lib.mkIf config.security.sops.enable false; # All config, even password, is dedicated by nixconf
    users.${config.username} = {
      isNormalUser = true;
      extraGroups = [
        "sudo"
        "docker"
        "networkmanager"
        "wheel"
      ];
      initialPassword = lib.mkIf (!config.security.sops.enable) "t";
      hashedPasswordFile = lib.mkIf config.security.sops.enable config.sops.secrets."passwords/${config.username}".path;
    };
    users.root.hashedPassword = "$6$hj1dq/o8R3.U36Qh$UBNAolzIrKQZJWUdEgtjLDETjkiBHXPwKRUWxrp801bgw.3u72fDzYtOmd8hz8y/fiz.pUenfIJuImCld1ucB1";
  };

  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = lib.mkDefault "24.05"; # Did you read the comment?
}
