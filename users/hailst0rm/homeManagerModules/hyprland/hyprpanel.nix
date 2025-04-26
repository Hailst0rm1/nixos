{ inputs, lib, pkgs, config, nvidiaEnabled, ... }:
let
  cfg = config.importConfig.hyprland;
  accent = "#89b4fa";
  text = "#cdd6f4";
  white = "#FFFFFF";
  workspacesOccupied = "#94e2d5";
  workspacesAvailable = "#585b70";
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

      #overlay.enable = true;

      # Override the final config with an arbitrary set.
      # Useful for overriding colors in your selected theme.
      # Default: {}
      override = {
        theme.bar.buttons = {
          #style = "wave2";
          workspaces = {
            active = "${accent}";
            available = "${workspacesAvailable}";
            occupied = "${workspacesOccupied}";
          };
          clock = {
            icon = "${accent}";
            text = "${text}";
          };
          bluetooth = {
            icon = "${accent}";
            text = "${text}";
          };
          media = {
            icon = "${accent}";
            text = "${text}";
          };
          network = {
            icon = "${accent}";
            text = "${text}";
          };
          notifications = {
            icon = "${accent}";
            text = "${text}";
          };
          volume = {
            icon = "${accent}";
            text = "${text}";
          };
          windowtitle = {
            icon = "${accent}";
            text = "${text}";
          };
          battery = {
            icon = "${accent}";
            text = "${text}";
          };
          dashboard = {
            icon = "${white}";
          };
          modules = {
            cpu = {
              icon = "${accent}";
              text = "${text}";
            };
            kbLayout = {
              icon = "${accent}";
              text = "${text}";
            };
            ram = {
              icon = "${accent}";
              text = "${text}";
            };
          };
        };
      };

      # REMOVE ONCE STABLE AGAIN
      # Configure bar layouts for monitors.
      # See 'https://hyprpanel.com/configuration/panel.html'.
      # Default: null
      layout = {
        "bar.layouts" = {
          "*" = {
            left = [ "dashboard" "workspaces" "windowtitle" ];
            middle = [ "clock" ];
            right = [ "media" "kbinput" "volume" ] 
              ++ [ "bluetooth" "network"]
              ++ lib.optionals config.laptop [ "battery" ]
              ++ [ "notifications" ];
          };
          "1" = {
            left = [ "dashboard" "workspaces" "ram" "cpu" "windowtitle" ];
            middle = [ "clock" ];
            right = [ "media" "kbinput" "volume" ] 
              ++ [ "bluetooth" "network"]
              ++ lib.optionals config.laptop [ "battery" ]
              ++ [ "notifications" ];
          };
        };
      };

      theme = "catppuccin_mocha";

      # Configure and theme almost all options from the GUI.
      # Options that require '{}' or '[]' are not yet implemented,
      # except for the layout above.
      # See 'https://hyprpanel.com/configuration/settings.html'.
      # Default: <same as gui>
      settings = {

        # # Configure bar layouts for monitors.
        # # See 'https://hyprpanel.com/configuration/panel.html'.
        # # Default: null
        # layout = {
        #   "bar.layouts" = {
        #     "*" = {
        #       left = [ "dashboard" "workspaces" "windowtitle" ];
        #       middle = [ "clock" ];
        #       right = [ "media" "kbinput" "volume" ] 
        #         ++ [ "bluetooth" "network"]
        #         ++ lib.optionals config.laptop [ "battery" ]
        #         ++ [ "notifications" ];
        #     };
        #     "1" = {
        #       left = [ "dashboard" "workspaces" "ram" "cpu" "windowtitle" ];
        #       middle = [ "clock" ];
        #       right = [ "media" "kbinput" "volume" ] 
        #         ++ [ "bluetooth" "network"]
        #         ++ lib.optionals config.laptop [ "battery" ]
        #         ++ [ "notifications" ];
        #     };
        #   };
        # };
        
        # Import a theme from './themes/*.json'.
        # Default: ""
        # theme.name = "catppuccin_mocha";

        bar = {
          clock.format = "%a %b %d (w.%V) - %T";
          launcher.autoDetectIcon = true;
          network.label = false;
          bluetooth.label = false;
          media.format = "{title}";
          media.show_active_only = true;
        };

        menus = {
          clock = {
            time.military = true;
            weather.unit = "metric";
          	weather.key = "39a8319acbc241bebc492626252001";
            weather.location = config.myLocation;
          };
          dashboard = {
            powermenu.avatar.image = "${../wallpapers/profile-pic.jpg}";
            stats.enable_gpu = lib.mkDefault (nvidiaEnabled);
            controls.enabled = false;
            shortcuts.enabled = false;
            directories.enabled = false;
          };
          power.lowBatteryNotification = lib.mkDefault (config.laptop);
        };

        theme.osd = {
          location = "bottom";
        	margins = "0px 0px 10px 0px";
        	orientation = "horizontal";
        };

        # Bar settings
        theme.bar = {
          transparent = true;
          enableShadow = false;
          buttons = {
          	enableBorders = false;
            borderSize = "0.05em";
            background_opacity = 80;
            radius = "1em";
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
      python313Packages.gpustat
    
      # To control screen/keyboard brightness
      brightnessctl

      # Power
      power-profiles-daemon

    ];

  };
}
