{
  pkgs,
  pkgs-unstable,
  lib,
  config,
  ...
}: let
  defaultDisplay = pkgs.writeText "default-display" ''
    [ ",highrr,auto,1" ];
  '';

  startScript = pkgs.writeShellScriptBin "start" ''

    ${pkgs.networkmanagerapplet}/bin/nm-applet --indicator &

    systemctl --user import-environment PATH &
    systemctl --user restart xdg-desktop-portal.service &

  '';

  hyprland-preview-share-picker = pkgs.callPackage ../../../../pkgs/hyprland-preview-share-picker/package.nix {};

  cfg = config.importConfig.hyprland;
in {
  config = lib.mkIf cfg.enable {
    home.sessionVariables.NIXOS_OZONE_WL = "1";

    home.file.".config/hypr/xdph.conf".text = lib.mkIf cfg.customScreenPicker ''
      screencopy {
        custom_picker_binary = ${hyprland-preview-share-picker}/bin/hyprland-preview-share-picker
      }
    '';

    wayland.windowManager.hyprland = {
      enable = true;
      portalPackage = null;
      xwayland.enable = true;
      systemd.enable = true;

      plugins = [
        pkgs.hyprlandPlugins.hyprsplit
        pkgs.hyprlandPlugins.hyprspace
      ];

      # extraConfig = ''
      #   bind = $mainMod,V,submap,passthru
      #   submap = passthru
      #   bind = $mainMod,Escape,submap,reset
      #   submap = reset
      # '';

      settings = {
        general = {
          gaps_in = 5;
          gaps_out = 10;
          border_size = 3;

          layout = "master";
          #layout = "dwindle";

          "col.active_border" = lib.mkForce "rgb(${lib.removePrefix "#" cfg.accentColourHex})";
        };

        master = {
          mfact = 0.5;
        };

        workspace =
          lib.mapAttrsToList (
            monitor: orientation: "m[${monitor}], layoutopt:orientation:${orientation}"
          )
          cfg.monitorOrientations;

        group = {
          "col.border_active" = lib.mkForce "rgb(${lib.removePrefix "#" cfg.accentColourHex})";
          groupbar = {
            font_size = 11;
            font_weight_active = "bold";
            font_weight_inactive = "bold";
            keep_upper_gap = false;
            "col.active" = lib.mkForce "rgb(${lib.removePrefix "#" cfg.accentColourHex})";
          };
        };

        decoration = {
          active_opacity = 0.95;
          inactive_opacity = 0.9;
          rounding = 5;
          blur = {
            size = 8;
            passes = 2;
          };
          shadow = {
            enabled = true;
            range = 5;
            render_power = 3;
            color = lib.mkForce "rgb(${lib.removePrefix "#" cfg.accentColourHex})";
            color_inactive = lib.mkForce "rgb(1e1e2e)";
          };
        };

        env = [
          "ELECTRON_ENABLE_WAYLAND,1"
          "ELECTRON_OZONE_PLATFORM_HINT,auto"
        ];

        input = {
          kb_layout = config.keyboard;
          kb_options = "grp:win_space_toggle";
          touchpad = {
            middle_button_emulation = true;
          };
        };

        gesture = [
          "3, horizontal, workspace"
          "3, down, dispatcher, overview:open all"
          "3, up, dispatcher, overview:close all"
        ];

        # Use "displays" (scripts/displays.sh) to configure displays dynamically
        # This will load the configuration if one is set using "displays" - otherwise use default value
        monitor = let
          configFile = ../../hosts/displays/${config.hostname}.conf;
        in
          if builtins.pathExists configFile
          then import configFile
          else defaultDisplay;

        plugin = {
          hyprsplit = {
            num_workspaces = "5";
            persistent_workspaces = true;
          };
        };

        animations = {
          enabled = true;

          bezier = [
            "overshot, 0.05, 0.9, 0.1, 1.05"
            "smoothOut, 0.5, 0, 0.99, 0.99"
            "smoothIn, 0.5, -0.5, 0.68, 1.5"
            "myCurve, 0.5, 0.9, 0.1, 1.05"
          ];
          animation = [
            "windows, 1, 5, myCurve, slide"
            "windowsOut, 1, 3, myCurve"
            "windowsIn, 1, 3, myCurve"
            "windowsMove, 1, 4, myCurve, slide"
            "layersIn, 1, 3, myCurve"
            "layersOut, 1, 3, myCurve"
            "border, 1, 5, myCurve"
            "borderangle, 1, 8, myCurve"
            "fade, 1, 5, myCurve"
            "fadeDim, 1, 5, myCurve"
            "workspaces, 1, 5, default"
            "specialWorkspace, 0"
          ];
        };

        dwindle = {
          # See https://wiki.hyprland.org/Configuring/Dwindle-Layout/ for more
          pseudotile = true; # master switch for pseudotiling. Enabling is bound to mainMod + P in the keybinds section below
          preserve_split = true; # you probably want this
          smart_split = true;
        };

        "$mainMod" = "ALT";
        #"$mainMod" = "SUPER";

        bind =
          [
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
            "$mainMod SHIFT, E, movegroupwindow, b"
            "$mainMod SHIFT, I, movegroupwindow, f"
            "$mainMod CONTROL SHIFT, H, moveintogroup, l"
            "$mainMod CONTROL SHIFT, L, moveintogroup, r"
            "$mainMod CONTROL SHIFT, K, moveintogroup, u"
            "$mainMod CONTROL SHIFT, J, moveintogroup, d"
            "$mainMod CONTROL SHIFT, I, moveoutofgroup, r"
            "$mainMod, P, pseudo, # dwindle"
            "$mainMod SHIFT, J, togglesplit, # dwindle"

            # Clipboard
            "$mainMod, C, sendshortcut, CTRL, Insert,"
            "$mainMod, V, sendshortcut, SHIFT, Insert,"
            "$mainMod, A, sendshortcut, CTRL, A,"
            "$mainMod, X, sendshortcut, CTRL, X,"
            "$mainMod, Z, sendshortcut, CTRL, Z,"
            "$mainMod, Y, sendshortcut, CTRL, Y,"

            # Applications
            "$mainMod, return, exec, GTK_IM_MODULE=simple ${config.terminal}"
            "$mainMod, P, exec, hyprpicker -alq"
            "$mainMod, SPACE, exec, ${cfg.appLauncher} -show drun"
            "$mainMod, R, exec, ${cfg.appLauncher} -show run"
            "$mainMod, W, exec, ${cfg.appLauncher} -show window"
            "$mainMod SHIFT, return, exec, ${config.browser}"
            "$mainMod, N, exec, ${config.fileManager}"
            "$mainMod, B, exec, GTK_IM_MODULE=simple ${config.terminal} -e htop"
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
            then 5
            else n
          )}") [
            1
            2
            3
            4
            5
            0
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
      # Applauncher
      #(pkgs.${cfg.appLauncher})
      (
        if cfg.appLauncher == "rofi"
        then pkgs.rofi
        else pkgs.${cfg.appLauncher}
      )

      # ---Clipboard
      wl-clipboard
      #xclip
      clipnotify

      # ---Colour picker
      hyprpicker

      # ---Display settings
      nwg-displays

      # ---File manager
      (pkgs.${config.fileManager})
      (
        if config.fileManager == "nautilus"
        then pkgs.file-roller
        else []
      )

      # ---Gnome applications
      (pkgs.${config.image})
      (pkgs.${config.video})
      gedit # Text editor
      gnome-calculator
      gnome-music
      evince # Document viewer
      parlatype # Media player

      # ---Lockscreen
      (pkgs.${cfg.lockscreen})

      # ---Networkmanager
      networkmanagerapplet

      # ---Notifications
      (pkgs.${cfg.notifications})

      # ---OSD
      # Add config in hyprland/default.nix?
      #swayosd

      # --Plugins
      hyprlandPlugins.hyprsplit
      hyprlandPlugins.hyprspace

      # ---Screenrecorder
      wl-screenrec

      # ---Screenshot
      grim
      slurp
      hyprshot

      # ---Topbar
      (pkgs.${cfg.panel})

      # ---Terminal
      #(pkgs.${config.terminal})

      # ---Wallpaper
      (pkgs-unstable.${cfg.wallpaper})
      waypaper # GUI wallpaper picker
      ffmpeg_6 # Video converter

      # ---Other
      playerctl
      (lib.mkIf cfg.customScreenPicker hyprland-preview-share-picker)
    ];
  };
}
