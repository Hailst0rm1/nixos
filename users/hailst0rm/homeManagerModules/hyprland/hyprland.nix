{
  pkgs,
  pkgs-unstable,
  lib,
  config,
  ...
}: let
  defaultDisplay = [",highrr,auto,1"];

  startScript = pkgs.writeShellScriptBin "start" ''

    ${pkgs.networkmanagerapplet}/bin/nm-applet --indicator &

    systemctl --user import-environment PATH &
    systemctl --user restart xdg-desktop-portal.service &

  '';

  hyprland-preview-share-picker = pkgs-unstable.hyprland-preview-share-picker; # official pkg (not in stable 26.05; unstable 0.2.1 == old pin)

  # Hyprland 0.55 made sendshortcut's window argument mandatory — an empty
  # third field now fails with "invalid args" instead of defaulting to the
  # focused window, so every call below passes `activewindow` explicitly.
  # Clipboard helpers: use Ctrl+Shift+C/V for terminals, Ctrl+C/V for everything else
  clip-copy = pkgs.writeShellScript "clip-copy" ''
    class=$(hyprctl activewindow -j | ${pkgs.jq}/bin/jq -r '.class')
    case "$class" in
      com.mitchellh.ghostty|org.wezfurlong.wezterm|kitty|Alacritty|foot)
        hyprctl dispatch sendshortcut "CTRL SHIFT, C, activewindow"
        # Strip HTML from clipboard - terminals set text/html which Electron apps
        # misinterpret with line breaks between formatted spans
        sleep 0.05
        ${pkgs.wl-clipboard}/bin/wl-paste -n -t text/plain 2>/dev/null | ${pkgs.wl-clipboard}/bin/wl-copy
        ;;
      *)
        hyprctl dispatch sendshortcut "CTRL, C, activewindow"
        ;;
    esac
  '';

  clip-paste = pkgs.writeShellScript "clip-paste" ''
    class=$(hyprctl activewindow -j | ${pkgs.jq}/bin/jq -r '.class')
    case "$class" in
      com.mitchellh.ghostty|org.wezfurlong.wezterm|kitty|Alacritty|foot)
        # Text pastes via Ctrl+Shift+V (works for shells, local Claude Code, and
        # SSH sessions — bracketed paste forwards it through the pty). Only a
        # clipboard IMAGE needs plain Ctrl+V, which Claude Code reads directly
        # from the local clipboard; images can't cross SSH anyway.
        case "$(${pkgs.wl-clipboard}/bin/wl-paste --list-types 2>/dev/null)" in
          *image/*) hyprctl dispatch sendshortcut "CTRL, V, activewindow" ;;
          *) hyprctl dispatch sendshortcut "CTRL SHIFT, V, activewindow" ;;
        esac
        ;;
      *)
        hyprctl dispatch sendshortcut "CTRL, V, activewindow"
        ;;
    esac
  '';

  # Vim-arrow with per-app exception: pass Ctrl+<key> through to Obsidian and
  # VSCode, remap to arrow direction everywhere else.
  vim-arrow = pkgs.writeShellScript "vim-arrow" ''
    key="$1"
    direction="$2"
    class=$(hyprctl activewindow -j | ${pkgs.jq}/bin/jq -r '.class')
    # Matched case-insensitively on a substring: Obsidian's app_id is
    # md.Obsidian on Wayland (it was plain "obsidian" when this list was
    # written, which is why the exception silently stopped matching), and
    # VSCode reports Code on XWayland but code natively.
    case "''${class,,}" in
      *obsidian*|code)
        hyprctl dispatch sendshortcut "CTRL, $key, activewindow"
        ;;
      *)
        # wtype, not sendshortcut: sendshortcut delivers to a toplevel window,
        # and serpantinum's popups are layer-shell surfaces, so the arrow went
        # to whatever window sat behind the panel. wtype injects through the
        # virtual-keyboard protocol carrying its own (empty) modifier state, so
        # the arrow reaches the focused surface as a bare Left/Right/Up/Down —
        # evdev-level injectors like ydotool instead inherit the Ctrl still
        # physically held, turning Ctrl+h into a word jump and missing QML
        # `Shortcut { sequence: "Left" }` handlers entirely.
        ${pkgs.wtype}/bin/wtype -k "$direction"
        ;;
    esac
  '';

  cfg = config.importConfig.hyprland;

  # Home Manager renders `plugins = [...]` as `exec-once=hyprctl plugin load
  # <path>`, which only runs once the whole config has already been parsed. So
  # every `split:` bind below is read while hyprsplit's dispatchers still do not
  # exist and Hyprland reports "Invalid dispatcher, requested split:... does not
  # exist" for each one, in a red error box on every launch. (The binds do end
  # up working — Hyprland resolves the dispatcher again at press time.)
  #
  # hyprlang's own `plugin = <path>` keyword loads at parse time instead, and
  # HM's `sourceFirst` (default true) hoists `source` above the binds, so the
  # dispatchers are registered before anything references them.
  pluginLoad = pkgs.writeText "hyprland-plugins.conf" ''
    plugin = ${pkgs.hyprlandPlugins.hyprsplit}/lib/libhyprsplit.so
    plugin = ${pkgs.hyprlandPlugins.hyprspace}/lib/libhyprspace.so
  '';
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
      configType = "hyprlang";
      portalPackage = null;
      xwayland.enable = true;
      systemd.enable = true;

      # extraConfig = ''
      #   bind = $mainMod,V,submap,passthru
      #   submap = passthru
      #   bind = $mainMod,Escape,submap,reset
      #   submap = reset
      # '';

      settings = {
        # Hoisted to the top of the config by sourceFirst — see pluginLoad.
        source = ["${pluginLoad}"];

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
          # "3, down, dispatcher, overview:open all"
          # "3, up, dispatcher, overview:close all"
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
            "$mainMod SHIFT, J, layoutmsg, togglesplit # dwindle"

            # Clipboard (Ctrl+Shift+C/V for terminals, Ctrl+C/V for other apps)
            "$mainMod, C, exec, ${clip-copy}"
            "$mainMod, V, exec, ${clip-paste}"
            "$mainMod, A, sendshortcut, CTRL, A, activewindow"
            "$mainMod, X, sendshortcut, CTRL, X, activewindow"
            "$mainMod, Z, sendshortcut, CTRL, Z, activewindow"
            "$mainMod, Y, sendshortcut, CTRL, Y, activewindow"

            # Applications
            "$mainMod, return, exec, GTK_IM_MODULE=simple ${config.terminal}"
            "$mainMod, P, exec, hyprpicker -alq"
            "$mainMod SHIFT, return, exec, ${config.browser}"
            "$mainMod, N, exec, ${config.fileManager}"
            # "$mainMod, B, exec, GTK_IM_MODULE=simple ${config.terminal} -e htop"
            "$mainMod, B, exec, missioncenter"
          ]
          ++ (
            # serpantinum's launcher is a single fuzzy app+math launcher, not
            # rofi's `-show <mode>` — R (run-only) and W (window-switcher)
            # have no serpantinum equivalent, so they're dropped there.
            if cfg.appLauncher == "serpantinum"
            then [
              "$mainMod, SPACE, exec, serpantinum msg toggle launcher"
            ]
            else [
              "$mainMod, SPACE, exec, ${cfg.appLauncher} -show drun"
              "$mainMod, R, exec, ${cfg.appLauncher} -show run"
              "$mainMod, W, exec, ${cfg.appLauncher} -show window"
            ]
          )
          ++ lib.optionals (!cfg.quickshell.ilyamiro.enable && cfg.screenshot == "hyprshot") [
            ", PRINT, exec, hyprshot -m region -o $HOME/Pictures/Screenshots"
          ]
          ++ [
            # Workspaces
            "$mainMod, O, overview:toggle, all"
            "$mainMod, D, split:swapactiveworkspaces, current +1"
            "$mainMod, G, split:grabroguewindows"
            "$mainMod, mouse_down, split:workspace, e+1"
            "$mainMod, mouse_up, split:workspace, e-1"

            # Zoom
            "$mainMod SHIFT, mouse_up, exec, hyprctl keyword cursor:zoom_factor \"$(hyprctl getoption cursor:zoom_factor | awk 'NR==1 {factor = $2; if (factor < 1) {factor = 1}; print factor * 2.00}')\""
            "$mainMod SHIFT, mouse_down, exec, hyprctl keyword cursor:zoom_factor \"$(hyprctl getoption cursor:zoom_factor | awk 'NR==1 {factor = $2; if (factor < 1) {factor = 1}; print factor / 2.00}')\""
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

          # Vim-style arrow keys (global, override all apps), injected with wtype
          # so they reach layer-shell panels as well as windows — see vim-arrow.
          # j/k are routed through a wrapper so Obsidian and VSCode keep their native Ctrl+J/K.
          "CTRL, h, exec, ${pkgs.wtype}/bin/wtype -k Left"
          "CTRL, j, exec, ${vim-arrow} j Down"
          "CTRL, k, exec, ${vim-arrow} k Up"
          "CTRL, l, exec, ${pkgs.wtype}/bin/wtype -k Right"

          # Word-step (Ctrl+Shift+h/l -> Ctrl+Left/Right)
          "CTRL SHIFT, h, sendshortcut, CTRL, Left, activewindow"
          "CTRL SHIFT, l, sendshortcut, CTRL, Right, activewindow"
        ];

        bindm = [
          # Move/resize windows with mainMod + LMB/RMB and dragging
          "$mainMod, mouse:272, movewindow"
          "$mainMod, mouse:273, resizewindow"
        ];

        bindl =
          [
            ",switch:on:Lid Switch,exec, hyprctl keyword monitor \"eDP-1, disable\""
            ",switch:off:Lid Switch,exec, hyprctl keyword monitor \"eDP-1, 1920x1200,0x0,1\""
            ", XF86AudioPlay, exec, playerctl play-pause"
            ", XF86AudioPrev, exec, playerctl previous"
            ", XF86AudioNext, exec, playerctl next"
            ", XF86KbdLightOnOff, exec, toggle-backlit-keys"
          ]
          ++ (
            # v1's osd_trigger.sh only deploys under quickshell.ilyamiro — serpantinum
            # has its own OSD, driven by its own CLI (see migration plan / audit doc).
            if cfg.quickshell.serpantinum.enable
            then [
              ", XF86AudioMute, exec, serpantinum volume mute-toggle"
              ", XF86AudioMicMute, exec, serpantinum volume mic-toggle"
            ]
            else [
              ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle && bash ~/.config/quickshell/osd/osd_trigger.sh volume"
              ", XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle && bash ~/.config/quickshell/osd/osd_trigger.sh mic"
            ]
          );

        bindel =
          if cfg.quickshell.serpantinum.enable
          then [
            ", XF86MonBrightnessUp, exec, serpantinum brightness raise"
            ", XF86MonBrightnessDown, exec, serpantinum brightness lower"
            ", XF86AudioRaiseVolume, exec, serpantinum volume raise"
            ", XF86AudioLowerVolume, exec, serpantinum volume lower"
          ]
          else [
            ", XF86MonBrightnessUp, exec, brightnessctl set +5% && bash ~/.config/quickshell/osd/osd_trigger.sh brightness"
            ", XF86MonBrightnessDown, exec, brightnessctl set 5%- && bash ~/.config/quickshell/osd/osd_trigger.sh brightness"
            ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ && bash ~/.config/quickshell/osd/osd_trigger.sh volume"
            ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- && bash ~/.config/quickshell/osd/osd_trigger.sh volume"
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

    home.packages = with pkgs;
      [
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

        # ---Screenshot
        grim
        slurp
        hyprshot

        # ---Topbar
        (pkgs.${cfg.panel})

        # ---Terminal
        #(pkgs.${config.terminal})

        # ---Wallpaper
        (
          # nixpkgs renamed swww -> awww 2026-03-22; the "swww" wallpaper
          # selector is our own naming, kept as-is.
          if cfg.wallpaper == "swww"
          then pkgs-unstable.awww
          else pkgs-unstable.${cfg.wallpaper}
        )
        waypaper # GUI wallpaper picker
        ffmpeg_6 # Video converter

        # ---Other
        playerctl
        (lib.mkIf cfg.customScreenPicker hyprland-preview-share-picker)
      ]
      # serpantinum's package already bundles gpu-screen-recorder/wf-recorder;
      # wl-screenrec would be a redundant second recorder on those hosts.
      ++ lib.optionals (!cfg.quickshell.serpantinum.enable) [
        pkgs.wl-screenrec
      ];
  };
}
