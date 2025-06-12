{
  inputs,
  config,
  hostname,
  lib,
  modulesPath,
  ...
}: {
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix"
    ../../nixosModules/system/colemak-se_keyboard.nix
    ../../nixosModules/variables.nix
    ../../nixosModules/system/utils.nix
    ../../nixosModules/themes/stylix.nix
    # ../../nixosModules/desktop/default.nix
    ../../nixosModules/graphics/nvidia/default.nix

    # inputs.nixos-hardware.nixosModules.common-cpu-intel
    # inputs.nixos-hardware.nixosModules.common-gpu-nvidia
    # inputs.nixos-hardware.nixosModules.common-pc-ssd
  ];

  nixpkgs.hostPlatform = "x86_64-linux";

  # variables.nix
  username = "";
  hostname = hostname;
  # systemArch = "x86_64-linux";

  # desktop/default.nix
  # Gnome is default
  # desktopEnvironment.name = "gnome";

  services.openssh.enable = false;

  # Bluetooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = false;

  system = {
    keyboard.colemak-se = true;
    theme = {
      enable = false;
      name = "catppuccin-mocha";
    };
  };

  # Allow unfree software
  nixpkgs.config.allowUnfree = true;

  # Set your time zone.
  time.timeZone = "Europe/Stockholm";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";

  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.05"; # Did you read the comment?
}
