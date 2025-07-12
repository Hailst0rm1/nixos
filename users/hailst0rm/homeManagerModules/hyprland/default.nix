{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.importConfig.hyprland;
in {
  options.importConfig.hyprland = {
    enable = lib.mkEnableOption "Enable Hyprland setup.";

    panel = lib.mkOption {
      type = lib.types.str;
      default = "hyprpanel";
      description = "The default panel for Hyprland.";
    };

    accentColour = lib.mkOption {
      type = lib.types.enum [
        "rosewater"
        "flamingo"
        "pink"
        "mauve"
        "red"
        "maroon"
        "peach"
        "yellow"
        "green"
        "teal"
        "sky"
        "sapphire"
        "blue"
        "lavender"
      ];
      default = "blue";
      description = "The default accent theme for Hyprland.";
    };

    accentColourHex = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = let
        colourMap = {
          rosewater = "#f5e0dc";
          flamingo = "#f2cdcd";
          pink = "#f5c2e7";
          mauve = "#cba6f7";
          red = "#f38ba8";
          maroon = "#eba0ac";
          peach = "#fab387";
          yellow = "#f9e2af";
          green = "#a6e3a1";
          teal = "#94e2d5";
          sky = "#89dceb";
          sapphire = "#74c7ec";
          blue = "#89b4fa";
          lavender = "#b4befe";
        };
      in
        lib.attrByPath [config.importConfig.hyprland.accentColour] "#ffffff" colourMap;
      description = "Hex value for the selected accent colour.";
    };

    lockscreen = lib.mkOption {
      type = lib.types.str;
      default = "hyprlock";
      description = "The default lockscreen for Hyprland.";
    };

    appLauncher = lib.mkOption {
      type = lib.types.str;
      default = "rofi";
      description = "The default application launcher for Hyprland.";
    };

    notifications = lib.mkOption {
      type = lib.types.str;
      default = "swaync";
      description = "The notification manager for Hyprland.";
    };

    wallpaper = lib.mkOption {
      type = lib.types.str;
      default = "swww";
      description = "The wallpaper manager for Hyprland.";
    };
  };
}
