{
  config,
  hostname,
  lib,
  ...
}: let
  # Lib
  myLib = import ../../myLib/generators.nix;
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    #myLib.validFiles ../../nixosModules
    #lib.filter 
      #(n: lib.strings.hasSuffix ".nix" n)
      #(lib.filesystem.listFilesRecursive ../../nixosModules)
  ];

  # variables.nix
  tnrsyuahrtsvar = {
    username = "hailst0rm";
    hostname = hostname;
    laptop = true;
    location = "Barkarby";
  };

  # desktop/default.nix
  # Gnome is default
  desktopEnvironment.name = "hyprland";

  # graphic
  graphicDriver.nvidia = {
    enable = true;
    type = "test";
  };

  security = {
    dnscrypt.enable = false;
    completePolkit.enable = false;
    yubikey.enable = false;
  };

  # Bluetooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = false;
  
  system = {
    # TODO: Kernel
    theme = "catppuccin-mocha";
    bootloader = "systemd";
    keyboard.colemak-se = true;
    firewall.enable = true;
    automatic = {
      upgrade = true;
      cleanup = true;
    };
  };

  virtualisation = {
    host = {
      vmware = true;
      qemu = true;
    };
    guest = {
      vmware = false;
      qemu = false;
    };
  };

  # Allow unfree software
  nixpkgs.config.allowUnfree = true;

  # Set your time zone.
  time.timeZone = "Europe/Stockholm";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.${config.username} = {
    isNormalUser = true;
    extraGroups = ["docker" "sudo" "networkmanager" "wheel"]; # Enable ‘sudo’ for the user.
    initialPassword = "t";
  };
    

  # # # # # # # # # # # !!!!!! # # # # # # # # # #
  # UNCOMMENT THIS SECTION WHILE INSTALLING      #
  #                                              #
  #security.pam = {
  #  u2f.enable = lib.mkForce false;
  #  services.login.u2fAuth = lib.mkForce false;
  #  services.login.u2fAuth = lib.mkForce false;
  #}
  # # # # # # # # # # # !!!!!! # # # # # # # # # #

  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.05"; # Did you read the comment?
}

