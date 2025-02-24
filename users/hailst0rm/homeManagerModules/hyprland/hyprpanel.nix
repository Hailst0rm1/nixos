{ inputs, lib, pkgs, config, nvidiaEnabled, ... }:
let
  cfg = config.importConfig.hyprland;
in {
  imports = [ inputs.hyprpanel.homeManagerModules.hyprpanel ];

  config = lib.mkIf (cfg.panel == "hyprpanel" || cfg.notifications == "hyprpanel") {
    programs.hyprpanel = {

      # Enable the module.
      # Default: false
      enable = true;

      # Add '/nix/store/.../hyprpanel' to your
      # Hyprland config 'exec-once'.
      # Default: false
      hyprland.enable = true;

      # Fix the overwrite issue with HyprPanel.
      # See below for more information.
      # TLDR: Allows for live preview via gui
      # Default: false
      overwrite.enable = true;

      # Import a theme from './themes/*.json'.
      # Default: ""
      theme = "catppuccin_mocha";

      # Override the final config with an arbitrary set.
      # Useful for overriding colors in your selected theme.
      # Default: {}
      override = {
        theme.bar.buttons.style = "wave2";
      };

      # Configure bar layouts for monitors.
      # See 'https://hyprpanel.com/configuration/panel.html'.
      # Default: null
      layout = {
        "bar.layouts" = {
          "*" = {
            left = [ "dashboard" "workspaces" "windowtitle" ];
            middle = [ "clock" ];
            right = [ "media" "volume" "kbinput" ] 
              ++ lib.optionals config.laptop [ "battery" ] 
              ++ [ "bluetooth" "network" "notifications" ];
          };
          "1" = {
            left = [ "dashboard" "workspaces" "ram" "cpu" "windowtitle" ];
            middle = [ "clock" ];
            right = [ "media" "volume" "kbinput" ] 
              ++ lib.optionals config.laptop [ "battery" ] 
              ++ [ "bluetooth" "network" "notifications" ];
          };
        };
      };

      # Configure and theme almost all options from the GUI.
      # Options that require '{}' or '[]' are not yet implemented,
      # except for the layout above.
      # See 'https://hyprpanel.com/configuration/settings.html'.
      # Default: <same as gui>
      settings = {
        bar.clock.format = "%a %b %d (w.%V) - %T";
        bar.launcher.autoDetectIcon = true;
        bar.network.label = false;
        bar.bluetooth.label = false;
        bar.media.format = "{title}";
        bar.media.show_active_only = true;

        menus.clock = {
          time.military = true;
          weather.unit = "metric";
        	weather.key = "39a8319acbc241bebc492626252001";
          weather.location = config.myLocation;
        };

        menus.dashboard.powermenu.avatar.image = "${../wallpapers/profile-pic.jpg}";

        menus.dashboard.stats.enable_gpu = lib.mkDefault (nvidiaEnabled);
        menus.power.lowBatteryNotification = lib.mkDefault (config.laptop);
        menus.dashboard.controls.enabled = false;
        menus.dashboard.shortcuts.enabled = false;
        menus.dashboard.directories.enabled = false;

        theme.osd = {
          location = "bottom";
        	margins = "0px 0px 10px 0px";
        	orientation = "horizontal";
        };

        # Bar settings
        theme.bar = {
          transparent = true;
          enableShadow = false;
          bar.buttons = {
          	enableBorders = true;
            borderSize = "0.05em";
          };
        };
	
        theme.font = {
          name = "${config.stylix.fonts.monospace.name}";
          size = "14px";
        };

        wallpaper.enable = false;
      };
    };

    # Dependencies
    home.packages = with pkgs; [
      hyprpanel

      # ---Forced
      ags
      wireplumber
      libgtop
      bluez
      bluez-tools
      networkmanager
      dart-sass
      wl-clipboard
      upower
      gvfs
    
      # ---Optional

      # Tracking GPU Usage
      python3 
      python313Packages.gpustat
    
      # To control screen/keyboard brightness
      brightnessctl

      # Power
      power-profiles-daemon

    ];

  };
}
