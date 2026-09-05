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

    customScreenPicker = lib.mkEnableOption "Enable Hyprland Custom Screen Picker.";

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
      default = config.palette.${config.importConfig.hyprland.accentColour};
      description = "Hex value for the selected accent colour, in the active theme's palette.";
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

    screenshot = lib.mkOption {
      type = lib.types.enum ["hyprshot" "serpantinum"];
      default = "hyprshot";
      description = "The screenshot tool for Hyprland.";
    };

    notifications = lib.mkOption {
      type = lib.types.str;
      default = "swaync";
      description = "The notification manager for Hyprland.";
    };

    wallpaper = lib.mkOption {
      type = lib.types.str;
      default = "mpvpaper";
      description = "The wallpaper manager for Hyprland.";
    };

    quickshell.ilyamiro = {
      enable = lib.mkEnableOption "QuickShell desktop shell (replaces panel, notifications, lockscreen, screenshot)";

      openweatherCityId = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "OpenWeatherMap City ID for weather data.";
      };

      lockIcon = lib.mkOption {
        type = lib.types.path;
        default = ../../../../assets/images/nixos-logo.png;
        description = "Icon image displayed in the lock screen circle.";
      };
    };

    quickshell.serpantinum.enable = lib.mkEnableOption "Serpantinum v2 Quickshell desktop shell (replaces panel, notifications, lockscreen; supersedes quickshell.ilyamiro)";

    monitorOrientations = lib.mkOption {
      type = lib.types.attrsOf (lib.types.enum ["left" "right" "top" "bottom" "center"]);
      default = {};
      example = {
        "DP-1" = "top";
        "HDMI-A-1" = "left";
      };
      description = ''
        Set master layout orientation per monitor.
        Use monitor name (e.g., "DP-1", "HDMI-A-1", "eDP-1") as the key.
        Valid orientations: left, right, top, bottom, center.
      '';
    };
  };
}
