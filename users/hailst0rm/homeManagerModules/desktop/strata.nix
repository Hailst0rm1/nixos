{
  config,
  lib,
  pkgs,
  ...
}: let
  colors = config.lib.stylix.colors;
  toml = pkgs.formats.toml {};
  python = pkgs.python3.withPackages (ps: [ps.tomlkit]);
  stylix = config.importConfig.stylix.enable;

  # Reapplied on every switch; keys not listed here stay owned by the Settings UI.
  settings =
    {
      check_for_updates = false;
      release_channel = "stable";
      tenxer_mode = true;
      show_keybinding_hints = false;
      element_glow = false;
      window_show_close = false;
      browser_mode = "columns";
      folders_first = true;
      sort_key = "name";
      sort_direction = "ascending";
      show_hidden = false;
      restore_tabs = true;
      sidebar_show_music = false;
      sidebar_show_desktop = false;
    }
    // lib.optionalAttrs stylix {
      mode = "theme";
      theme = "stylix";
    };
in {
  config = lib.mkIf (config.fileManager == "strata") {
    xdg.configFile."strata/themes/stylix.toml" = lib.mkIf stylix {
      force = true;
      source = toml.generate "strata-stylix.toml" {
        name = "Stylix";
        background = "#${colors.base00}";
        surface = "#${colors.base01}";
        text = "#${colors.base05}";
        accent = config.importConfig.hyprland.accentColourHex;
        danger = "#${colors.base08}";
        muted = "#${colors.base02}";
        highlight = "#${colors.base02}";
        border = "#${colors.base03}";
        dim_text = "#${colors.base04}";
        syntax_keyword = "#${colors.base0E}";
        syntax_string = "#${colors.base0B}";
        syntax_constant = "#${colors.base09}";
        syntax_type = "#${colors.base0A}";
        syntax_preprocessor = "#${colors.base0C}";
      };
    };

    # Strata's "terminal here" (Ctrl+Alt+T) launches through xdg-terminal-exec.
    xdg.terminal-exec = {
      enable = true;
      settings.default = [
        (
          if config.terminal == "ghostty"
          then "com.mitchellh.ghostty.desktop"
          else "${config.terminal}.desktop"
        )
      ];
    };

    # Register Strata's already-working portal + FileManager1 integration where
    # its Settings → "System file manager" self-check looks. Nix serves these
    # from the profile (on XDG_DATA_DIRS) already; Strata only inspects
    # $XDG_DATA_HOME, so mirror the three files it checks for there.
    xdg.dataFile = {
      # Open/Save dialogs. The portal config already prefers "strata"
      # (nixosModules/desktop/hyprland.nix); these just need to exist.
      "xdg-desktop-portal/portals/strata.portal".source = "${pkgs.strata}/share/xdg-desktop-portal/portals/strata.portal";
      "dbus-1/services/org.freedesktop.impl.portal.desktop.strata.service".source = "${pkgs.strata}/share/dbus-1/services/org.freedesktop.impl.portal.desktop.strata.service";

      # Reveal in File Manager. Strata's check requires Exec to equal its own
      # current_exe, which on Nix is the wrapped binary, not $out/bin/strata.
      # shortcut: hardcodes makeWrapper's ".strata-wrapped" name, revisit if the wrapper changes.
      "dbus-1/services/io.github.lgse.Strata.FileManager1.service".text = ''
        [D-BUS Service]
        Name=org.freedesktop.FileManager1
        Exec=${pkgs.strata}/bin/.strata-wrapped --gapplication-service
      '';
    };

    # Keep preferences writable by Strata and preserve unrelated settings.
    # The opt-in marker stops Strata offering to rewrite the portal config Nix owns.
    home.activation.strataSettings = lib.hm.dag.entryAfter ["linkGeneration"] ''
      run ${python}/bin/python -c ${lib.escapeShellArg ''
        import json, sys
        from pathlib import Path
        import tomlkit

        path = Path(sys.argv[1])
        pinned = json.loads(sys.argv[2])
        settings = tomlkit.parse(path.read_text()) if path.exists() else tomlkit.document()
        settings.update(pinned)
        content = tomlkit.dumps(settings)
        assert all(tomlkit.parse(content)[k] == v for k, v in pinned.items())
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)

        marker = path.parent / "portal-opt-in-v1"
        if not marker.exists():
            marker.write_text("1\n")
      ''} ${lib.escapeShellArg "${config.xdg.configHome}/strata/settings.toml"} ${lib.escapeShellArg (builtins.toJSON settings)}
    '';
  };
}
