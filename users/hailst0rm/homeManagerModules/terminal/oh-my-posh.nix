{
  config,
  lib,
  ...
}: let
  accentHex = config.importConfig.hyprland.accentColourHex;

  # Shared theme base — parameterised by prompt prefix and accent color
  mkTheme = {
    promptPrefix ? "",
    accentColor ? "p:pink",
    pathColor ? accentHex,
  }: ''
    console_title_template = '{{ .Shell }} in {{ .Folder }}'
    version = 3
    final_space = true

    [palette]
      grey = '#C0BFBC'
      pink = '#FF69D0'

    [secondary_prompt]
      template = '${promptPrefix}❯❯ '
      foreground = '${accentColor}'
      background = 'transparent'

    [transient_prompt]
      template = '${promptPrefix}❯ '
      background = 'transparent'
      foreground_templates = ['{{if gt .Code 0}}red{{end}}', '{{if eq .Code 0}}${accentColor}{{end}}']

    [[blocks]]
      type = 'prompt'
      alignment = 'left'
      newline = true

      [[blocks.segments]]
        template = '{{ .Path }}'
        foreground = '${pathColor}'
        background = 'transparent'
        type = 'path'
        style = 'plain'

        [blocks.segments.properties]
          style = 'full'

      [[blocks.segments]]
        template = ' {{ .HEAD }}{{ if or (.Working.Changed) (.Staging.Changed) }}*{{ end }} <cyan>{{ if gt .Behind 0 }}⇣{{ end }}{{ if gt .Ahead 0 }}⇡{{ end }}</>'
        foreground = 'p:grey'
        background = 'transparent'
        type = 'git'
        style = 'plain'

        [blocks.segments.properties]
          branch_icon = ${"''"}
          commit_icon = '⦿'
          fetch_status = false

    [[blocks]]
      type = 'rprompt'
      overflow = 'hidden'

      [[blocks.segments]]
        template = '{{ .FormattedMs }}'
        foreground = 'yellow'
        background = 'transparent'
        type = 'executiontime'
        style = 'plain'

        [blocks.segments.properties]
          threshold = 5000

    [[blocks]]
      type = 'prompt'
      alignment = 'left'
      newline = true

      [[blocks.segments]]
        template = '${promptPrefix}❯'
        background = 'transparent'
        type = 'text'
        style = 'plain'
        foreground_templates = ['{{if gt .Code 0}}red{{end}}', '{{if eq .Code 0}}${accentColor}{{end}}']
  '';
in {
  config = lib.mkIf (config.shell == "zsh") {
    # User theme
    home.file.".config/oh-my-posh/.omp-zsh.toml".text = mkTheme {};

    # Root theme — skull prefix, red accent
    home.file.".config/oh-my-posh/.omp-zsh-root.toml".text = mkTheme {
      promptPrefix = "💀";
      accentColor = "red";
      pathColor = "red";
    };
  };
}
