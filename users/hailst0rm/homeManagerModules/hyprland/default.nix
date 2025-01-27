{
  pkgs,
  pkgs-unstable,
  lib,
  hostname,
  username,
  config,
  hyprland,
  ...
}: let
  # Config Variables
  # Todo: Import from user config
  terminal = "kitty";
  fileManager = "nautilus";
  appLauncher = "rofi -show drun";
  browser = "firefox";

  defaultDisplay = pkgs.WriteText "default-display" ''
    [ ",highrr,auto,1" ];
  '';
  
  startScript = pkgs.writeShellScriptBin "start" ''
    ${pkgs.swww}/bin/swww-daemon &

    ${pkgs.networkmanagerapplet}/bin/nm-applet --indicator &

    systemctl --user import-environment PATH &
    systemctl --user restart xdg-desktop-portal.service &

    # Wallpaper
    set -e
    while true; do
      BG=`find ${../../../../nixosModules/wallpapers} -name "*.gif" | shuf -n1`
      if pgrep swww-daemon >/dev/null; then
        swww img "$BG" \
          --transition-fps 60 \
          --transition-duration 2 \
          --transition-type random \
          --transition-pos top-right \
          --transition-bezier .3,0,0,.99 \
          --transition-angle 135 || true
        sleep 1800
      else
        (swww-daemon 1>/dev/null 2>/dev/null &) || true
        sleep 1
      fi
    done
  '';
  
  
in {

  imports = [
    #hyprland.homeManagerModules.default
    ./rofi.nix
    ./hyprlock.nix
    ./icons.nix
    #./swaync.nix
    #./waybar.nix
    ./hyprpanel.nix
  ];

  config = {

    services.hyprpaper.enable = lib.mkForce false;

    home.sessionVariables.NIXOS_OZONE_WL = "1";

    wayland.windowManager.hyprland = {
      enable = true;
      xwayland.enable = true;
      systemd.enable = true;

      plugins = [
	      pkgs.hyprlandPlugins.hyprsplit
        pkgs.hyprlandPlugins.hyprspace
      ];

      settings = {
        general = {
          gaps_in = 5;
          gaps_out = 10;
          border_size = 2;

          layout = "master";
        };

	env = [
	  "ELECTRON_ENABLE_WAYLAND,1"
	  "ELECTRON_OZONE_PLATFORM_HINT,auto"
	];

        input = {
          kb_layout = "colemak-se,se";
          kb_options = "grp:win_space_toggle";
        };

        monitor = let
          configFile = ../../hosts/displays/${hostname}.conf;
        in if builtins.pathExists configFile then import configFile else defaultDisplay;

        decoration = {
          rounding = 5;
        };

        animations = {
          enabled = true;

          bezier = [
            "overshot, 0.05, 0.9, 0.1, 1.05"
            "smoothOut, 0.5, 0, 0.99, 0.99"
            "smoothIn, 0.5, -0.5, 0.68, 1.5"
          ];
          animation = [
            "windows, 1, 5, overshot, slide"
            "windowsOut, 1, 3, smoothOut"
            "windowsIn, 1, 3, smoothOut"
            "windowsMove, 1, 4, smoothIn, slide"
            "border, 1, 5, default"
            "borderangle, 1, 8, default"
            "fade, 1, 5, smoothIn"
            "fadeDim, 1, 5, smoothIn"
            "workspaces, 1, 6, default"
          ];
        };

        dwindle = {
          # See https://wiki.hyprland.org/Configuring/Dwindle-Layout/ for more
          pseudotile = true; # master switch for pseudotiling. Enabling is bound to mainMod + P in the keybinds section below
          preserve_split = true; # you probably want this
        };

      	plugin = {
          hyprsplit = {
	          num_workspaces = "5";
	          persistent_workspaces = true;
	        };
        };
	
        "$mainMod" = "ALT";
        #"$mainMod" = "SUPER";

        bind =
          [
            # Show keybinds list
            "$mainMod, F1, exec, get-keybinds"

            # Navigation
            "$mainMod, left, movefocus, l"
            "$mainMod, right, movefocus, r"
            "$mainMod, up, movefocus, u"
            "$mainMod, down, movefocus, d"

            "$mainMod, h, movefocus, l"
            "$mainMod, l, movefocus, r"
            "$mainMod, k, movefocus, u"
            "$mainMod, j, movefocus, d"

            "$mainMod SHIFT, h, movewindow, l"
            "$mainMod SHIFT, l, movewindow, r"
            "$mainMod SHIFT, k, movewindow, u"
            "$mainMod SHIFT, j, movewindow, d"

      	    # Windows
            "$mainMod, Q, killactive,"
            "$mainMod SHIFT, M, exit,"
            "$mainMod SHIFT, F, togglefloating,"
            "$mainMod, F, fullscreen,"
            "$mainMod, G, togglegroup,"
            "$mainMod, E, changegroupactive, b"
            "$mainMod, I, changegroupactive, f"
            "$mainMod, P, pseudo, # dwindle"
            "$mainMod SHIFT, J, togglesplit, # dwindle"

      	    # Applications
            "$mainMod, return, exec, ${terminal}"
            "$mainMod, SPACE, exec, ${appLauncher}"
            "$mainMod, R, exec, rofi -show run"
            "$mainMod, W, exec, rofi -show window"
            "$mainMod SHIFT, return, exec, ${browser}"
            "$mainMod, N, exec, ${fileManager}"
            "$mainMod, S, exec, spotify --disable-gpu"
            "$mainMod, B, exec, ${terminal} btm"
      	    ", PRINT, exec, hyprshot -m region -o $HOME/Pictures/Screenshots"

    	    # Workspaces
          "$mainMod, O, overview:toggle, all"
          "$mainMod, D, split:swapactiveworkspaces, current +1"
          "$mainMod, G, split:grabroguewindows"
            "$mainMod, mouse_down, split:workspace, e+1"
            "$mainMod, mouse_up, split:workspace, e-1"
          ]
          ++ map (n: "$mainMod SHIFT, ${toString n}, split:movetoworkspace, ${toString (
            if n == 0
            then 5
            else n
          )}") [1 2 3 4 5 0]
          ++ map (n: "$mainMod, ${toString n}, split:workspace, ${toString (
            if n == 0
            then 10
            else n
          )}") [1 2 3 4 5 0
        ];

        binde = [
      	  # Resize windows
          "$mainMod SHIFT, h, moveactive, -20 0"
          "$mainMod SHIFT, l, moveactive, 20 0"
          "$mainMod SHIFT, k, moveactive, 0 -20"
          "$mainMod SHIFT, j, moveactive, 0 20"

          "$mainMod CTRL, l, resizeactive, 30 0"
          "$mainMod CTRL, h, resizeactive, -30 0"
          "$mainMod CTRL, k, resizeactive, 0 -10"
          "$mainMod CTRL, j, resizeactive, 0 10"
        ];

        bindm = [
          # Move/resize windows with mainMod + LMB/RMB and dragging
          "$mainMod, mouse:272, movewindow"
          "$mainMod, mouse:273, resizewindow"
        ];

      	bindl = [
        	  ",switch:on:Lid Switch,exec, hyprctl keyword monitor \"eDP-1, disable\""
        	  ",switch:off:Lid Switch,exec, hyprctl keyword monitor \"eDP-1, 1920x1200,0x0,1\""
        	  ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        	  ", XF86AudioPlay, exec, playerctl play-pause"
        	  ", XF86AudioPrev, exec, playerctl previous"
        	  ", XF86AudioNext, exec, playerctl next"
        	  ", XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle" 
        	  ", XF86KbdLightOnOff, exec, toggle-backlit-keys"
      	];

        bindel = [
        	  ", XF86MonBrightnessUp, exec, brightnessctl set +5%"
        	  ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"
        	  ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        	  ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ];

        exec-once = [
          "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
	  #"waybar"
          #"swaync -s ~/.config/swaync/style.css"
          "lxqt-policykit-agent"
          "${pkgs.bash}/bin/bash ${startScript}/bin/start"
        ];

        misc = {
         disable_hyprland_logo = true;
         disable_splash_rendering = true;
        };	  
      };
    };

    home.packages = with pkgs; [

      # ---Application launcher
      rofi-wayland
      #wofi

      # ---Clipboard
      wl-clipboard
      #xclip
      clipnotify

      # ---Colour picker
      hyprpicker

      # ---Display settings
      nwg-displays

      # ---File manager
      nautilus # File manager

      # ---Gnome applications
      #image-roll
      loupe # Image viewer
      totem # Video viewer
      gedit # Text editor
      gnome-calculator
      gnome-music 

      # ---Lockscreen
      hyprlock

      # ---Networkmanager
      networkmanagerapplet

      # ---Notifications
      #dunst
      #swaynotificationcenter

      # ---OSD
      #swayosd

      # ---Screenrecorder
      wl-screenrec

      # ---Screenshot
      grim
      slurp
      hyprshot

      # ---Topbar
      #waybar

      # ---Terminal
      kitty
      ghostty

      # ---Wallpaper
      swww
      ffmpeg_6 # Video converter

      # ---Other
      playerctl

      # --Test
      hyprlandPlugins.hyprsplit
      hyprlandPlugins.hyprspace
    ];
  };
}
