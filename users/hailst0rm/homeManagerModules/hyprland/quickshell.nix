{
  pkgs,
  lib,
  config,
  osConfig,
  ...
}: let
  cfg = config.importConfig.hyprland;
  qsCfg = cfg.quickshell.ilyamiro;

  # Resolve sops secret path for OpenWeather API key
  openweatherKeyPath =
    if (config.sops.secrets ? "services/openweather")
    then config.sops.secrets."services/openweather".path
    else "";

  qs = "~/.config/quickshell/qs_manager.sh";

  # Catppuccin Mocha accent color hex map
  accentHexMap = {
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
    sky = "#89dcfe";
    sapphire = "#74c7ec";
    blue = "#89b4fa";
    lavender = "#b4befe";
  };
  accentHex = accentHexMap.${cfg.accentColour};
  isLaptop = osConfig.laptop or false;

  # Generate SystemConfig.qml with Nix values baked in
  systemConfigQml = pkgs.writeText "SystemConfig.qml" ''
    import QtQuick
    Item {
        readonly property color accent: "${accentHex}"
        readonly property bool isLaptop: ${
      if isLaptop
      then "true"
      else "false"
    }
    }
  '';

  # Build a single config directory with static files + generated SystemConfig.qml
  # so QML type resolution finds SystemConfig in the same directory as TopBar.qml
  configDir = pkgs.runCommandLocal "quickshell-config" {} ''
    mkdir -p $out
    cp -rL ${./quickshell-config}/* $out/
    cp ${systemConfigQml} $out/SystemConfig.qml
  '';
in {
  config = lib.mkIf (cfg.enable && qsCfg.enable) {
    # Allow Home Manager to restart changed user services on activation
    systemd.user.startServices = "sd-switch";
    # Override conflicting components
    importConfig.hyprland = {
      panel = lib.mkForce "quickshell";
      notifications = lib.mkForce "quickshell";
      lockscreen = lib.mkForce "quickshell";
      # wallpaper is NOT forced — user picks via the existing wallpaper option:
      #   "mpvpaper" (default) = live video wallpapers
      #   "swww"              = still image rotation
    };

    # Deploy all QuickShell QML files, scripts, and assets
    # configDir is a single derivation containing static files + generated SystemConfig.qml
    xdg.configFile = {
      "quickshell" = {
        source = configDir;
        recursive = true;
      };

      # Weather API configuration — reads key from sops at runtime
      # No leading whitespace — weather.sh uses `export $(grep -v '^#' .env | xargs)`
      "quickshell/calendar/.env".text = lib.concatStringsSep "\n" [
        "OPENWEATHER_KEY_FILE=${openweatherKeyPath}"
        "OPENWEATHER_CITY_ID=${qsCfg.openweatherCityId}"
        "OPENWEATHER_UNIT=metric"
      ];
    };

    # Hyprland integration
    wayland.windowManager.hyprland.settings = {
      exec-once = [
        # quickshell-main, quickshell-topbar, quickshell-workspaces,
        # and quickshell-focusd are managed by systemd user services
        # wallpaper daemon (swww-daemon / mpvpaper) is started by swww.nix or mpvpaper.nix
      ];

      bind = [
        # Lock screen (QuickShell PAM lock)
        "$mainMod, ESCAPE, exec, bash ~/.config/quickshell/lock.sh"
        # Screenshot (QuickShell overlay)
        ", PRINT, exec, bash ~/.config/quickshell/screenshot.sh"
        # QuickShell widget toggles
        "$mainMod SHIFT, C, exec, bash ${qs} toggle calendar"
        "$mainMod SHIFT, N, exec, bash ${qs} toggle notifications"
        "$mainMod SHIFT, B, exec, bash ${qs} toggle battery"
        "$mainMod SHIFT, V, exec, bash ${qs} toggle volume"
        "$mainMod SHIFT, M, exec, bash ${qs} toggle music"
        "$mainMod SHIFT, A, exec, bash ${qs} toggle guide"
        "$mainMod SHIFT, S, exec, bash ${qs} toggle settings"
        "$mainMod SHIFT, T, exec, bash ${qs} toggle focustime"
        "$mainMod SHIFT, D, exec, bash ${qs} toggle monitors"
      ];

      windowrulev2 = [
        "float, class:^(com.gabm.satty)$"
        "center, class:^(com.gabm.satty)$"
        "size 80% 80%, class:^(com.gabm.satty)$"
      ];

      layerrule = [
        "blur, quickshell"
        "ignorezero, quickshell"
        "blur, qs-master"
        "ignorezero, qs-master"
      ];
    };

    # Systemd user services — restart on nixos-rebuild test
    systemd.user.services = {
      quickshell-main = {
        Unit = {
          Description = "QuickShell Main (widget overlay)";
          PartOf = ["graphical-session.target"];
          After = ["graphical-session.target"];
        };
        Service = {
          # QS_CONFIG store path changes on config edits — triggers sd-switch restart
          Environment = ["QS_CONFIG=${./quickshell-config}"];
          ExecStart = "${pkgs.quickshell}/bin/quickshell -p %h/.config/quickshell/Main.qml";
          Restart = "on-failure";
          RestartSec = 1;
          TimeoutStopSec = 5;
        };
        Install.WantedBy = ["graphical-session.target"];
      };

      quickshell-topbar = {
        Unit = {
          Description = "QuickShell TopBar";
          PartOf = ["graphical-session.target"];
          After = ["graphical-session.target"];
        };
        Service = {
          Environment = ["QS_CONFIG=${./quickshell-config}"];
          ExecStart = "${pkgs.quickshell}/bin/quickshell -p %h/.config/quickshell/TopBar.qml";
          Restart = "on-failure";
          RestartSec = 1;
          TimeoutStopSec = 5;
        };
        Install.WantedBy = ["graphical-session.target"];
      };

      quickshell-workspaces = {
        Unit = {
          Description = "QuickShell workspace state daemon";
          PartOf = ["graphical-session.target"];
          After = ["graphical-session.target"];
        };
        Service = {
          Environment = ["QS_CONFIG=${./quickshell-config}"];
          ExecStart = "${pkgs.bash}/bin/bash %h/.config/quickshell/workspaces.sh";
          Restart = "on-failure";
          RestartSec = 1;
          TimeoutStopSec = 5;
        };
        Install.WantedBy = ["graphical-session.target"];
      };

      quickshell-focusd = {
        Unit = {
          Description = "QuickShell focus timer daemon";
          PartOf = ["graphical-session.target"];
          After = ["graphical-session.target"];
        };
        Service = {
          Environment = ["QS_CONFIG=${./quickshell-config}"];
          ExecStart = "${pkgs.python3}/bin/python3 %h/.config/quickshell/focustime/focus_daemon.py";
          Restart = "on-failure";
          RestartSec = 1;
          TimeoutStopSec = 5;
        };
        Install.WantedBy = ["graphical-session.target"];
      };
    };

    # Required packages
    home.packages = with pkgs; [
      quickshell

      # Fonts: Iosevka for icons, JetBrainsMono for text
      nerd-fonts.iosevka
      nerd-fonts.jetbrains-mono

      # Screenshot/recording
      grim
      slurp
      wl-clipboard
      gpu-screen-recorder
      satty # Screenshot annotation editor
      zbar # QR code scanning from screenshots

      # Audio/media
      playerctl
      pamixer
      easyeffects # Equalizer for music widget
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
