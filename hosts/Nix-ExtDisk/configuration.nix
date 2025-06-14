{
  inputs,
  config,
  hostname,
  lib,
  ...
}: let
  device = "sda"; # IMPORTANT Set disk device (e.g. "sda", or "nvme0n1") - list with `lsblk`
  diskoConfig = "default"; # Change this if you have another disko config
in {
  imports =
    [
      # Includes hardware config from hardware scan
      ./hardware-configuration.nix

      # Disk partitioning
      inputs.disko.nixosModules.disko
      ../../nixosModules/system/bootloader.nix
      ../../disko/${diskoConfig}.nix
      {
        _module.args.device = device; # Sets the installation disk on disko-install
      }

      # Recursively imports all nixosModules
    ]
    ++ lib.filter
    (n: lib.strings.hasSuffix ".nix" n)
    (lib.filesystem.listFilesRecursive ../../nixosModules);

  # === TEMPORARY ===

  # Enables editing of hosts
  environment.etc.hosts.enable = false;
  environment.etc.hosts.mode = "0700";

  # ===

  # variables.nix
  username = "hailst0rm";
  hostname = hostname;
  systemArch = "x86_64-linux";
  laptop = true;
  removableMedia = true;
  myLocation = "Barkarby";

  # Red Teaming config
  cyber.redTools.enable = false;

  # desktop/default.nix
  # Gnome is default
  desktopEnvironment.name = "hyprland";

  # Display manager are currently built in the other desktops beside hyprland
  desktopEnvironment.displayManager = {
    enable = true;
    name = "sddm";
  };

  # graphic
  graphicDriver.nvidia = {
    enable = false;
    type = "default";
  };

  security = {
    sops.enable = false;
    firewall.enable = true; # Turn off for rev-shells etc
    dnscrypt.enable = false;
    completePolkit.enable = false;
    yubikey.enable = true;
  };

  # Bluetooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = false;

  system = {
    kernel = "zen";
    bootloader = "grub";
    keyboard.colemak-se = true;
    theme = {
      enable = true;
      name = "catppuccin-mocha";
    };
    automatic = {
      upgrade = false;
      cleanup = false;
    };
  };

  virtualisation = {
    host = {
      vmware = true;
      qemu = false;
    };
    guest = {
      vmware = false;
      qemu = false;
    };
  };

  # Hosted / Running services (nixosModules/services)
  services = {
    mattermost.enable = false;
    ollama.enable = false;
    open-webui.enable = false; # UI for local AI
  };

  # Allow unfree software
  nixpkgs.config.allowUnfree = true;

  # Set your time zone.
  time.timeZone = "Europe/Stockholm";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";

  # Define a user account. Don't forget to set a password with ‘passwd’.
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
  system.stateVersion = "24.05"; # Did you read the comment?
}
