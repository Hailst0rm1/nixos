{
  lib,
  config,
  pkgs,
  ...
}: let
  font_family = "${config.stylix.fonts.monospace.name}";
  #background = "${config.stylix.image}";

  hyprlock-blur = pkgs.writeShellScriptBin "hyprlock-blur" ''
    MONITOR1="$(hyprctl -j monitors | jq -r '.[0].name')"
    MONITOR2="$(hyprctl -j monitors | jq -r '.[1].name')"

    wait &&
    hyprlock
  '';
in {
  config = lib.mkIf (config.importConfig.hyprland.lockscreen == "hyprlock") {
    home.packages = [hyprlock-blur];

    wayland.windowManager.hyprland.settings.bind = [
      "SUPER, ESCAPE, exec, hyprlock-blur"
    ];

    home.sessionVariables = {
      MONITOR1 = "$(hyprctl -j monitors | jq -r '.[0].name')";
      MONITOR2 = "$(hyprctl -j monitors | jq -r '.[1].name')";
    };

    programs.zsh = {
      shellAliases = {hyprlock = "hyprlock-blur";};
      envExtra = ''
        export MONITOR1="$(hyprctl -j monitors | jq -r '.[0].name')"
        export MONITOR2="$(hyprctl -j monitors | jq -r '.[1].name')"
      '';
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

      # BACKGROUND
      background {
        monitor = $MONITOR1
        path = screenshot
        blur_passes = 2
        color = $base
      }

      background {
        monitor = $MONITOR2
        path = screenshot
        blur_passes = 2
        color = $base
      }

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

    home.file.".config/hypr/mocha.conf".text = ''

      $rosewater = rgb(f5e0dc)
      $rosewaterAlpha = f5e0dc

      $flamingo = rgb(f2cdcd)
      $flamingoAlpha = f2cdcd

      $pink = rgb(f5c2e7)
      $pinkAlpha = f5c2e7

      $mauve = rgb(cba6f7)
      $mauveAlpha = cba6f7

      $red = rgb(f38ba8)
      $redAlpha = f38ba8

      $maroon = rgb(eba0ac)
      $maroonAlpha = eba0ac

      $peach = rgb(fab387)
      $peachAlpha = fab387

      $yellow = rgb(f9e2af)
      $yellowAlpha = f9e2af

      $green = rgb(a6e3a1)
      $greenAlpha = a6e3a1

      $teal = rgb(94e2d5)
      $tealAlpha = 94e2d5

      $sky = rgb(89dceb)
      $skyAlpha = 89dceb

      $sapphire = rgb(74c7ec)
      $sapphireAlpha = 74c7ec

      $blue = rgb(89b4fa)
      $blueAlpha = 89b4fa

      $lavender = rgb(b4befe)
      $lavenderAlpha = b4befe

      $text = rgb(cdd6f4)
      $textAlpha = cdd6f4

      $subtext1 = rgb(bac2de)
      $subtext1Alpha = bac2de

      $subtext0 = rgb(a6adc8)
      $subtext0Alpha = a6adc8

      $overlay2 = rgb(9399b2)
      $overlay2Alpha = 9399b2

      $overlay1 = rgb(7f849c)
      $overlay1Alpha = 7f849c

      $overlay0 = rgb(6c7086)
      $overlay0Alpha = 6c7086

      $surface2 = rgb(585b70)
      $surface2Alpha = 585b70

      $surface1 = rgb(45475a)
      $surface1Alpha = 45475a

      $surface0 = rgb(313244)
      $surface0Alpha = 313244

      $base = rgb(1e1e2e)
      $baseAlpha = 1e1e2e

      $mantle = rgb(181825)
      $mantleAlpha = 181825

      $crust = rgb(11111b)
      $crustAlpha = 11111b
    '';
  };
}
