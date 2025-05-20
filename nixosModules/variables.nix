{ pkgs, lib, config, ... }:
# IMPORTANT: If you add changes here, you also need to add them in generators.nix so that HM inherits them
# and in HM config so that they are defined in config
{
  options = {
    username = lib.mkOption {
      type = lib.types.str;
      default = "hailst0rm";
      description = "The default username.";
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

    systemArch = lib.mkOption {
      type = lib.types.str;
      default = "x86_64-linux";
      description = "The target system architecture.";
    };

    myLocation = lib.mkOption {
      type = lib.types.str;
      default = "Stockholm";
      description = "Current physical location";
    };

    laptop = lib.mkEnableOption "Enable if computer is a laptop.";

    removableMedia = lib.mkEnableOption "Enable if OS is installed on a removable media (USB/External device).";

    cyber.redTools.enable =  lib.mkEnableOption "Enable for offensive tooling.";
  };
}
