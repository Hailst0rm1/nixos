# The active desktop colour set, resolved from `system.theme.name`.
#
# Consumers read `config.palette.<role>` instead of writing hexes, so switching
# a host's theme repaints every widget from one line. The role names are
# catppuccin's; see `lib/palettes.nix` for why, and for the sets themselves.
{
  lib,
  config,
  osConfig,
  ...
}: let
  palettes = import ../../../lib/palettes.nix {inherit lib;};
in {
  options.palette = lib.mkOption {
    type = lib.types.attrsOf lib.types.str;
    readOnly = true;
    default = palettes.forTheme osConfig.system.theme.name;
    description = "Colour set for the active theme, keyed by catppuccin role name.";
  };

  # Waybar, swaync and rofi read colours through GTK CSS rather than Nix, so
  # they consume this block instead of interpolating each role individually.
  options.paletteCss = lib.mkOption {
    type = lib.types.lines;
    readOnly = true;
    default =
      lib.concatStringsSep "\n"
      (lib.mapAttrsToList (name: hex: "@define-color ${name} ${hex};") config.palette);
    description = "The active palette as GTK `@define-color` declarations.";
  };
}
