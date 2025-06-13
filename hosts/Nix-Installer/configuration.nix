{
  inputs,
  config,
  hostname,
  lib,
  ...
}: {
  imports =
    [
      # Recursively imports all nixosModules
    ]
    ++ lib.filter
    (n: lib.strings.hasSuffix ".nix" n)
    (lib.filesystem.listFilesRecursive ../../nixosModules);

  # variables.nix
  username = "hailst0rm";
  hostname = hostname;
  systemArch = "x86_64-linux";
  removableMedia = true;
  myLocation = "Barkarby";

  nixpkgs.hostPlatform = config.systemArch;

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
    # bootloader = "grub";
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
  };

  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.05"; # Did you read the comment?
}
