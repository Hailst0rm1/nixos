{ pkgs, lib, ... }:
{
  options.var = {
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
      default = "${pkgs.lib.getEnv "HOME"}/.nixos";
      description = "The directory containing NixOS configurations.";
    };

    system = lib.mkOption {
      type = lib.types.str;
      default = "x86_64-linux";
      description = "The target system architecture.";
    };

    location = lib.mkOption {
      type = lib.types.str;
      default = "Stockholm";
      description = "Current physical location";
    };

    laptop = lib.mkEnableOption "Enable if computer is a laptop.";
  };
}
