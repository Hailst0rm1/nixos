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
    ./hardware-configuration.nix
  ] ++ lib.filter 
        (n: lib.strings.hasSuffix ".nix" n)
        (lib.filesystem.listFilesRecursive ../../nixosModules);
          
  # === TEMPORARY ===
  environment.etc.hosts.enable = false;
  environment.etc.hosts.mode = "0700";
  # ===


  # variables.nix
  username = "hailst0rm";
  hostname = hostname;
  systemArch = "x86_64-linux";
  laptop = false;
  myLocation = "Barkarby";

  # desktop/default.nix
  # Gnome is default
  desktopEnvironment.name = "hyprland";

  # Display manager are currently built in the other desktops beside hyprland
  desktopEnvironment.displayManager = {
    enable = true;
    name = "sddm";
  };

  # Red Teaming config
  cyber.redTools.enable = true;

  # graphic
  graphicDriver.nvidia = {
    enable = true;
    type = "default";
  };

  security = {
    firewall.enable = true; # Turn off for rev-shells etc
    dnscrypt.enable = false;
    completePolkit.enable = false;
    yubikey.enable = true;
  };

  # Bluetooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = false;
  
  system = {
    # kernel = "zen";
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
      vmware = false;
      qemu = false;
    };
    guest = {
      vmware = false;
      qemu = false;
    };
  };

  # Hosted / Running services (nixosModules/services)
  services = {
    mattermost.enable = true;
    ollama.enable = false;
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

