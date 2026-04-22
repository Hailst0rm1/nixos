{
  pkgs,
  lib,
  config,
  osConfig,
  ...
}: let
  cfg = config.importConfig.hyprland;
  qsCfg = cfg.quickshell;
in {
  config = lib.mkIf (cfg.enable && qsCfg.enable) {
    # Override conflicting components
    importConfig.hyprland = {
      panel = lib.mkForce "quickshell";
      notifications = lib.mkForce "quickshell";
      lockscreen = lib.mkForce "quickshell";
      wallpaper = lib.mkForce "swww";
    };

    # Deploy all QuickShell QML files, scripts, and assets
    xdg.configFile = {
      "quickshell" = {
        source = ./quickshell-config;
        recursive = true;
      };

      # Weather API configuration
      "quickshell/calendar/.env" = lib.mkIf (qsCfg.openweatherKey != "") {
        text = ''
          OPENWEATHER_KEY=${qsCfg.openweatherKey}
          OPENWEATHER_CITY_ID=${qsCfg.openweatherCityId}
          OPENWEATHER_UNIT=metric
        '';
      };
    };

    # Hyprland integration
    wayland.windowManager.hyprland.settings = {
      exec-once = [
        "swww-daemon"
        "quickshell -p ~/.config/quickshell/Main.qml"
        "quickshell -p ~/.config/quickshell/TopBar.qml"
        "python3 ~/.config/quickshell/focustime/focus_daemon.py &"
        "bash ~/.config/quickshell/workspaces.sh &"
      ];

      layerrule = [
        "blur, quickshell"
        "ignorezero, quickshell"
        "blur, qs-master"
        "ignorezero, qs-master"
      ];
    };

    # Required packages
    home.packages = with pkgs; [
      quickshell

      # Screenshot/recording
      grim
      slurp
      wl-clipboard
      gpu-screen-recorder
      zbar # QR code scanning from screenshots

      # Audio/media
      playerctl
      pamixer
      cava

      # Network/Bluetooth
      bluez
      bluez-tools

      # Shell script dependencies
      jq
      curl
      bc
      inotify-tools # inotifywait for watchers
      brightnessctl
      imagemagick # Screenshot editing
      socat # Hyprland socket communication

      # Python for focus timer and wallpaper scripts (python3 provided by utils.nix)
    ];
  };
}
