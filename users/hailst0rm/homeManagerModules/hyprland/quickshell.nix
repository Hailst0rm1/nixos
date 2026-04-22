{
  pkgs,
  lib,
  config,
  osConfig,
  ...
}: let
  cfg = config.importConfig.hyprland;
  qsCfg = cfg.quickshell;

  # Resolve sops secret path for OpenWeather API key
  openweatherKeyPath =
    if (config.sops.secrets ? "services/openweather")
    then config.sops.secrets."services/openweather".path
    else "";

  qs = "~/.config/quickshell/qs_manager.sh";
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

      # Weather API configuration — reads key from sops at runtime
      # No leading whitespace — weather.sh uses `export $(grep -v '^#' .env | xargs)`
      "quickshell/calendar/.env".text = lib.concatStringsSep "\n" ([
        "OPENWEATHER_KEY_FILE=${openweatherKeyPath}"
        "OPENWEATHER_CITY_ID=${qsCfg.openweatherCityId}"
        "OPENWEATHER_UNIT=metric"
      ]);
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

      bind = [
        # Screenshot (QuickShell overlay)
        ", PRINT, exec, bash ~/.config/quickshell/screenshot.sh"
        # QuickShell widget toggles
        "$mainMod, S, exec, bash ${qs} toggle calendar"
        "$mainMod SHIFT, N, exec, bash ${qs} toggle notifications"
        "$mainMod SHIFT, W, exec, bash ${qs} toggle wallpaper"
        "$mainMod SHIFT, B, exec, bash ${qs} toggle battery"
        "$mainMod SHIFT, V, exec, bash ${qs} toggle volume"
        "$mainMod SHIFT, G, exec, bash ${qs} toggle guide"
        "$mainMod SHIFT, P, exec, bash ${qs} toggle settings"
        "$mainMod SHIFT, T, exec, bash ${qs} toggle focustime"
        "$mainMod SHIFT, D, exec, bash ${qs} toggle monitors"
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

      # Icon font (Nerd Font for QML icon glyphs)
      nerd-fonts.iosevka

      # Screenshot/recording
      grim
      slurp
      wl-clipboard
      gpu-screen-recorder
      zbar # QR code scanning from screenshots

      # Audio/media
      playerctl
      pamixer
      pulseaudio # pactl — needed by volume/audio scripts
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
