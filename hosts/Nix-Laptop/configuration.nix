{
  config,
  ...
}: let
  # Lib
  myLib = import ../../myLib/generators.nix;
in {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    myLib.validFiles ../../nixosModules

    # Keep for now - remove once they are modularly added:
    ../../nixosModules/default.nix
    #../../nixosModules/zen-browser.nix
    ../../nixosModules/graphics/nvidia/test.nix
    #../../nixosModules/graphics/intel/default.nix
    ../../nixosModules/themes/stylix.nix
  ];

  # variables.nix
  systemVariables = {
    username = "hailst0rm";
    hostname = "Nix-Laptop";
    bootloader = "systemd";
    kernel = "zen";
  };

  # default.nix
  nixosModules.default = true;

  nixpkgs.config.allowUnfree = true;
  # # # # # # # # # # # !!!!!! # # # # # # # # # #
  # UNCOMMENT THIS SECTION WHILE INSTALLING      #
  #                                              #
  #security.pam = {
  #  u2f.enable = lib.mkForce false;
  #  services.login.u2fAuth = lib.mkForce false;
  #  services.login.u2fAuth = lib.mkForce false;
  #}
  # # # # # # # # # # # !!!!!! # # # # # # # # # #

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

  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.05"; # Did you read the comment?
}

