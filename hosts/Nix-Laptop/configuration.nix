{
  inputs,
  config,
  hostname,
  lib,
  ...
}: let
  device = "nvme0n1"; # IMPORTANT Set disk device (e.g. "sda", or "nvme0n1") - list with `lsblk`
in {
  imports =
    [
      # Includes hardware config from hardware scan
      ./hardware-configuration.nix

      # Secrets
      inputs.sops-nix.nixosModules.sops

      # Disk partitioning
      inputs.disko.nixosModules.disko
      ../../nixosModules/system/bootloader.nix
      ./disks.nix
      {
        _module.args.device = device; # Set disk device (e.g. "sda", or "nvme0n1") - list with `lsblk`
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
  removableMedia = false;
  myLocation = "Barkarby";

  # Red Teaming config
  cyber.redTools.enable = true;

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
    sops.enable = true;
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
      upgrade = true;
      cleanup = true;
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

  # Secrets
  sops = {
    secrets.hailst0rm-password.neededForUsers = true; # User password
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${config.username} = {
    isNormalUser = true;
    extraGroups = ["docker" "sudo" "networkmanager" "wheel"]; # Enable ‘sudo’ for the user.
    # hashedPasswordFile = config.sops.secrets."${config.username}-password".path;
    hashedPasswordFile = config.sops.secrets.hailst0rm-password.path;
    # initialPassword = "t";
  };

  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.05"; # Did you read the comment?
}
