{
  config,
  lib,
  ...
}:
# Shared options imported by both NixOS modules and Home Manager.
# Values are set in each host's configuration.nix and propagated to HM
# via generators.nix extraSpecialArgs or the module system.
{
  options = {
    username = lib.mkOption {
      type = lib.types.str;
      default = "hailst0rm";
      description = "The username of the user.";
    };

    hostname = lib.mkOption {
      type = lib.types.str;
      default = "Nix-Laptop";
      description = "The default hostname.";
    };

    nixosDir = lib.mkOption {
      type = lib.types.str;
      default = "/home/${config.username}/.nixos";
      description = "The directory containing NixOS configurations.";
    };

    # Note: System architecture is now handled via nixpkgs.hostPlatform in hardware-configuration.nix
    # Access it via config.nixpkgs.hostPlatform.system

    myLocation = lib.mkOption {
      type = lib.types.str;
      default = "Stockholm";
      description = "Current physical location";
    };

    laptop = lib.mkEnableOption "Enable if computer is a laptop.";

    removableMedia = lib.mkEnableOption "Enable if OS is installed on a removable media (USB/External device).";

    cyber.redTools.enable = lib.mkEnableOption "Enable for offensive tooling.";
  };
}
