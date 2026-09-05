{
  inputs,
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.importConfig.hyprland;
  qsCfg = cfg.quickshell.serpantinum;

  accentHex = cfg.accentColourHex;

  # Same avatar/lock-screen asset as the v1 fork's quickshell.ilyamiro.lockIcon,
  # kept as an internal default rather than a second mirrored option.
  avatarIcon = ../../../../assets/images/nixos-logo.png;

  # Reimplements the upstream HM module's settings-merge (nix/hm-module.nix)
  # so the activation script below can drop its `if [ ! -e ]` guard — Nix is
  # the sole source of truth for settings.json (decision 12).
  jsonFormat = pkgs.formats.json {};
  templateSettings = builtins.fromJSON (builtins.readFile "${inputs.serpantinum}/config/serpantinum/settings.json");
  userSettings = lib.filterAttrsRecursive (_: v: v != null) config.programs.serpantinum.settings;
  mergedSettings = lib.recursiveUpdate templateSettings userSettings;
  settingsFile = jsonFormat.generate "serpantinum-settings.json" mergedSettings;
  settingsTarget = "${config.xdg.configHome}/serpantinum/settings.json";
  # Hardcoded upstream in scripts/caching.sh as "$HOME/.local/state/serpantinum",
  # not XDG_STATE_HOME-derived — mirror the literal path, not config.xdg.stateHome.
  stateDir = "${config.home.homeDirectory}/.local/state/serpantinum";

  # bin/serpantinum, bin/serpantinumd and singletons/Updater.qml all read the
  # running version from this file and fall back to a hardcoded "2.0.0" when it
  # is absent — which is what the guide's title showed. Upstream's install.sh
  # writes it; nothing does on NixOS, so write it from the derivation's own
  # version and it can never drift from the package.
  versionFile = pkgs.writeText "serpantinum-version" ''
    SERPANTINUM_VERSION=${config.programs.serpantinum.package.version}
  '';
in {
  imports = [inputs.serpantinum.homeManagerModules.default];

  config = lib.mkIf (cfg.enable && qsCfg.enable) {
    # mkOverride 900 sits between mkDefault (1000) and a plain definition
    # (100): serpantinum wins over the mkDefault "rofi"/"hyprshot" in
    # hosts/default.nix, but an explicit per-host override still wins over
    # serpantinum. See migration plan "Why mkOverride 900 and not mkForce" —
    # mkForce here would make hyprpanel/swaync/hyprlock/waybar permanently
    # unreachable the way the v1 fork's quickshell.nix does.
    importConfig.hyprland = {
      panel = lib.mkOverride 900 "serpantinum";
      notifications = lib.mkOverride 900 "serpantinum";
      lockscreen = lib.mkOverride 900 "serpantinum";
      appLauncher = lib.mkOverride 900 "serpantinum";
      screenshot = lib.mkOverride 900 "serpantinum";
    };

    # InfoWidget and the quickactions hardcode font.family: "Font Awesome 6
    # Free Solid" for their icons, but serpantinum only bundles Nerd Fonts —
    # without this the icons fall back to whatever font happens to claim
    # those PUA codepoints, rendering as the wrong glyph.
    home.packages = [pkgs.font-awesome_6];

    # The clipboard panel is a cliphist front end: clipboard/clip_fetcher.py
    # shells out to `cliphist list`. serpantinum bundles the cliphist binary but
    # starts no watcher, so with nothing running `cliphist store` the database
    # stays empty and the panel renders a search field over an empty list. This
    # runs the two wl-paste watchers (text and images) that feed it.
    services.cliphist.enable = true;

    programs.serpantinum = {
      enable = true;
      # Built via overlays.default against our nixpkgs 26.05, not
      # self.packages.<system>.default (serpantinum's own pinned unstable).
      package = pkgs.serpantinum;

      settings = {
        general = {
          language = "en";
          avatarPath = "${avatarIcon}";
          muteSfx = true;
          weatherUnit = "metric";
          weatherInterval = 15;
          quickactions = true;
        };

        # `> cmd` in the launcher shells out through this prefix; upstream
        # defaults it to kitty, which this system does not install.
        launcher.terminalCommand = "${config.terminal} -e";

        bar = {
          position = "top";
          style = "modular"; # LOAD-BEARING — group boxes only render in this style
          width = 100;
          opacity = 100; # matches v1's fully-opaque bar
          time.format = "HH:mm:ss"; # matches the current fork's clock
          # Must track hyprland.nix's plugin.hyprsplit.num_workspaces — patch 5
          # (WorkspacesWidget.qml) uses this to compute each monitor's real
          # workspace-id range (mon_id * workspaceCount + 1 ...).
          workspaceCount = 5;
          modules = {
            left = ["left" "workspaces" ["media"]];
            center = [["timedate" "weather"]];
            # "tray" (running-app systray) dropped — v1 never showed one.
            # sysmon (cpu/ram/temp) stands alone, left of the kb/wifi/bt/vol/bat group.
            right = ["info" "sysmon" ["kb" "wifi" "bt" "vol" "bat"]];
          };
        };

        theme = {
          fontFamily = "JetBrainsMono Nerd Font";
          borderRadius = 20; # = barHeight/2 -> true capsules
          matugen = false; # true repaints the accent from the wallpaper at runtime
          activePreset = "Mocha";
          # Neutrals + semantic red/green come straight from the active theme;
          # the decorative accent-role keys collapse to the one accent — see
          # docs/serpantinum-v2-migration-plan.md "The accent collapse".
          colors =
            config.palette
            // {
              mauve = accentHex;
              blue = accentHex;
              teal = accentHex;
              sapphire = accentHex;
              peach = accentHex;
              # red / green deliberately left at palette values — semantic, not decorative
            };
        };

        idle.enabled = false;

        notifications = {
          dnd = false;
          position = "top right";
          sound = true;
        };
      };
    };

    # Nix is the source of truth: overwrite settings.json unconditionally on
    # every activation, overriding upstream's `if [ ! -e ]` guard (decision 12).
    #
    # Must run BEFORE reloadSystemd, not just after writeBoundary. Home Manager
    # orders same-priority DAG entries alphabetically, so upstream's
    # `entryAfter ["writeBoundary"]` puts serpantinumSettings *after*
    # reloadSystemd — serpantinumd restarts against the old (or, on first
    # activation, absent) settings.json. singletons/Config.qml watches that path
    # with a FileView whose watch cannot fire for a file that did not exist when
    # the watch was armed, so `Config.dataReady` stays false forever and
    # bar/Bar.qml's `visible: barConfigReady` never flips — the bar silently
    # never appears.
    #
    # first_launch.done is pre-created so scripts/first_launch.sh (spawned by
    # serpantinumd) short-circuits: it otherwise runs the branded Start.qml
    # intro, force-opens the guide, and picks a random wallpaper through
    # serpantinum's own engine, which mpvpaper owns here (decision 7).
    home.activation.serpantinumSettings = lib.mkForce (lib.hm.dag.entryBetween ["reloadSystemd"] ["writeBoundary"] ''
      run mkdir -p ${lib.escapeShellArg (builtins.dirOf settingsTarget)}
      run install -m 0644 ${settingsFile} ${lib.escapeShellArg settingsTarget}
      run mkdir -p ${lib.escapeShellArg stateDir}
      run touch ${lib.escapeShellArg "${stateDir}/first_launch.done"}
      run install -m 0644 ${versionFile} ${lib.escapeShellArg "${stateDir}/version"}
    '');

    # `serpantinumd start` takes an flock on /tmp/serpantinumd.lock and exits 1
    # with "Daemon is already running" when it cannot get it. On a Home Manager
    # switch the incoming instance can reach that flock while the outgoing one
    # still holds it — every child the daemon spawned inherits the lock fd, so
    # the lock outlives the main process by however long the tree takes to die.
    # systemd's defaults then retry five times at 100ms, all of them inside that
    # window, hit StartLimitBurst, and give up for good: the bar never comes
    # back and only a manual `systemctl --user reset-failed` revives it.
    #
    # ExecStartPre waits for the lock instead of racing it, so the first
    # ExecStart already owns it. RestartSec keeps a retry from burning the
    # start limit in one second if something else takes the lock anyway.
    systemd.user.services.serpantinum.Service = {
      ExecStartPre = "${pkgs.util-linux}/bin/flock -w 15 /tmp/serpantinumd.lock true";
      RestartSec = 2;
    };

    # v1's SHIFT+S (settings) and SHIFT+D (monitors) have no v2 equivalent —
    # those popups were folded into guide tabs, and Nix is now
    # the settings source of truth (decision 12) — dropped, not repointed.
    # Guarded per-selector (not just qsCfg.enable) so an explicit per-host
    # override — priority 100, beats this module's mkOverride 900 — is honored.
    wayland.windowManager.hyprland.settings.bind =
      [
        "$mainMod SHIFT, C, exec, serpantinum msg toggle calendar"
        "$mainMod SHIFT, N, exec, serpantinum msg toggle network"
        "$mainMod SHIFT, V, exec, serpantinum msg toggle volume"
        "$mainMod SHIFT, M, exec, serpantinum msg toggle music"
        "$mainMod SHIFT, A, exec, serpantinum msg toggle guide"
        # v2 folds battery into the SystemPanel — no standalone battery toggle
        "$mainMod SHIFT, B, exec, serpantinum msg toggle system"
        # Clipboard history — its own window, mutually exclusive with the
        # launcher rather than part of the shared popup stack.
        "$mainMod SHIFT, P, exec, serpantinum msg toggle clipboard"
        # Timer/stopwatch/pomodoro/alarm — moved out of the quickactions
        # sidebar into a panel of its own, so it reclaims v1's focustime bind.
        "$mainMod SHIFT, T, exec, serpantinum msg toggle timer"
        # System monitor. R for "resources" — S and T were already taken, and
        # SHIFT+B is the SystemPanel sidebar, which is a different thing.
        "$mainMod SHIFT, R, exec, serpantinum msg toggle sysmon"
      ]
      ++ lib.optionals (cfg.notifications == "serpantinum") [
        "$mainMod SHIFT, D, exec, serpantinum msg toggle notifications"
      ]
      ++ lib.optionals (cfg.lockscreen == "serpantinum") [
        "$mainMod, ESCAPE, exec, serpantinum lock"
      ]
      ++ lib.optionals (cfg.screenshot == "serpantinum") [
        ", PRINT, exec, serpantinum screenshot"
      ];
  };
}
