{
  inputs,
  config,
  hostname,
  lib,
  ...
}: let
  device = "nvme0n1"; # IMPORTANT Set disk device (e.g. "sda", or "nvme0n1") - list with `lsblk`
  diskoConfig = "default";
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
        _module.args.device = device; # Set disk device (e.g. "sda", or "nvme0n1") - list with `lsblk`
      }

      # NixOS-Hardware - Seem to not work properly on this system?
      # List: https://github.com/NixOS/nixos-hardware/blob/master/flake.nix
      # inputs.nixos-hardware.nixosModules.common-cpu-intel
      # inputs.nixos-hardware.nixosModules.common-gpu-nvidia
      # inputs.nixos-hardware.nixosModules.common-gpu-intel
      # inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd
      # inputs.nixos-hardware.nixosModules.common-pc-ssd

      # Recursively imports all nixosModules
    ]
    ++ lib.filter
    (n: lib.strings.hasSuffix ".nix" n)
    (lib.filesystem.listFilesRecursive ../../nixosModules);

  # variables.nix
  username = "hailst0rm";
  hostname = hostname;
  systemArch = "x86_64-linux";
  removableMedia = false;
  laptop = false;
  myLocation = "Barkarby";

  # desktop/default.nix
  # Gnome is default
  desktopEnvironment.name = "gnome";

  # Display manager are currently built in the other desktops beside hyprland
  # desktopEnvironment.displayManager = {
  #   enable = true;
  #   name = "sddm";
  # };

  # graphic
  # graphicDriver.intel.enable = true;
  # graphicDriver.nvidia = {
  #   enable = true;
  #   type = "default";
  # };

  # Bluetooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = false;

  system = {
    bootloader = "grub";
    keyboard.colemak-se = true;
    theme = {
      enable = true;
      name = "catppuccin-mocha";
    };
  };

  # Hosted / Running services (nixosModules/services)
  services = {
    openssh.enable = false;
  };

  # Allow unfree software
  nixpkgs.config.allowUnfree = true;

  # Set your time zone.
  time.timeZone = "Europe/Stockholm";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";

  # Define a user account.
  users = {
    users.${config.username} = {
      isNormalUser = true;
      extraGroups = [
        "sudo"
        "docker"
        "networkmanager"
        "wheel"
      ];
      initialPassword = "t";
    };
    users.root.hashedPassword = "$6$hj1dq/o8R3.U36Qh$UBNAolzIrKQZJWUdEgtjLDETjkiBHXPwKRUWxrp801bgw.3u72fDzYtOmd8hz8y/fiz.pUenfIJuImCld1ucB1";
  };

  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.05"; # Did you read the comment?
}
