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
