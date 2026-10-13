{
  config,
  lib,
  pkgs,
  ...
}: let
  colors = config.lib.stylix.colors;
  toml = pkgs.formats.toml {};
  python = pkgs.python3.withPackages (ps: [ps.tomlkit]);
in {
  config = lib.mkIf (config.fileManager == "strata" && config.importConfig.stylix.enable) {
    xdg.configFile."strata/themes/stylix.toml" = {
      force = true;
      source = toml.generate "strata-stylix.toml" {
        name = "Stylix";
        background = "#${colors.base00}";
        surface = "#${colors.base01}";
        text = "#${colors.base05}";
        accent = "#${colors.base0D}";
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

    # Keep preferences writable by Strata and preserve unrelated settings.
    home.activation.strataTheme = lib.hm.dag.entryAfter ["linkGeneration"] ''
      run ${python}/bin/python -c ${lib.escapeShellArg ''
        import sys
        from pathlib import Path
        import tomlkit

        path = Path(sys.argv[1])
        settings = tomlkit.parse(path.read_text()) if path.exists() else tomlkit.document()
        settings.update(mode="theme", theme="stylix", check_for_updates=False)
        content = tomlkit.dumps(settings)
        assert tomlkit.parse(content)["theme"] == "stylix"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
      ''} ${lib.escapeShellArg "${config.xdg.configHome}/strata/settings.toml"}
    '';
  };
}
