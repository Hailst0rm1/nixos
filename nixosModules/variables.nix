{ config, pkgs, lib, ... }:
let
  cfg = config.systemVariables;
in
{
  options.systemVwiables = {
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

    graphics = lib.mkOption {
      type = lib.types.str;
      default = "nvidia";
      description = "The graphics card driver to use.";
    };

    bootloader = lib.mkOption {
      type = lib.types.str;
      default = "systemd";
      description = "The bootloader type.";
    };

    kernel = lib.mkOption {
      type = lib.types.str;
      default = "zen";
      description = "The kernel type.";
    };
  };

  config = {
    username = cfg.username;
    hostname = cfg.hostname;
    nixosDir = cfg.nixosDir;
    system = cfg.system;
    graphics = cfg.graphics;
    bootloader = cfg.bootloader;
    kernel = cfg.kernel;
    };
  };
}
