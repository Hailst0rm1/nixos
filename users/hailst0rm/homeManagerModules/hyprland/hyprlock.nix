{
  lib,
  config,
  pkgs,
  ...
}: let
  font_family = "${config.stylix.fonts.monospace.name}";
  #background = "${config.stylix.image}";

  hyprlock-blur = pkgs.writeShellScriptBin "hyprlock-blur" ''
    wait &&
    hyprlock
  '';

  # Generate background blocks for all monitors
  # Get monitor names from the monitorOrientations configuration
  monitorNames = builtins.attrNames config.importConfig.hyprland.monitorOrientations;

  generateBackgrounds =
    lib.concatMapStringsSep "\n" (monitor: ''
      background {
        monitor = ${monitor}
        path = screenshot
        blur_passes = 2
        color = $base
      }
    '')
    monitorNames;
in {
  config = lib.mkIf (config.importConfig.hyprland.enable && config.importConfig.hyprland.lockscreen == "hyprlock") {
    home.packages = [hyprlock-blur];

    wayland.windowManager.hyprland.settings.bind = [
      "SUPER, ESCAPE, exec, hyprlock-blur"
    ];

    programs.zsh = {
      shellAliases = {hyprlock = "hyprlock-blur";};
    };

    home.file.".config/hypr/hyprlock.conf".text = ''
      source = $HOME/.config/hypr/mocha.conf

      $accent = rgb(${lib.removePrefix "#" config.importConfig.hyprland.accentColourHex})
      $accentAlpha = ${lib.removePrefix "#" config.importConfig.hyprland.accentColourHex}
      $font = ${font_family}

      # GENERAL
      general {
        disable_loading_bar = true
        hide_cursor = true
      }

      # BACKGROUND - Generated for all monitors
      ${generateBackgrounds}

      # TIME
      label {
        monitor =
        text = $TIME
        color = $text
        font_size = 48
        font_family = $font
        position = 0, 100
        halign = center
        valign = center
      }

      # DATE
      label {
        monitor =
        text = cmd[update:43200000] date +"%A, %d %B %Y"
        color = $text
        font_size = 16
        font_family = $font
        position = 0, 50
        halign = center
        valign = center
      }

      # INPUT FIELD
      input-field {
        monitor =
        size = 300, 60
        outline_thickness = 4
        dots_size = 0.2
        dots_spacing = 0.2
        dots_center = true
        outer_color = $accent
        inner_color = $surface0
        font_color = $text
        fade_on_empty = false
        placeholder_text = <span foreground="##$textAlpha">󰌾  <span foreground="##$accentAlpha">$USER</span></span>
        hide_input = false
        check_color = $accent
        fail_color = $red
        fail_text = <i>$FAIL <b>($ATTEMPTS)</b></i>
        capslock_color = $yellow
        position = 0, -47
        halign = center
        valign = center
      }
    '';

    # Filename kept as mocha.conf so the source line above stays put; the
    # values follow whichever theme is active.
    home.file.".config/hypr/mocha.conf".text =
      lib.concatStringsSep "\n"
      (lib.mapAttrsToList (
          name: hex: let
            raw = lib.removePrefix "#" hex;
            # `\$` rather than an indented string: `$${` is Nix's escape for a
            # literal `${`, so `$${name}` would emit the name uninterpolated.
          in "\$${name} = rgb(${raw})\n\$${name}Alpha = ${raw}\n"
        )
        config.palette);
  };
}
