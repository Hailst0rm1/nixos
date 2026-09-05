# Named desktop colour sets, keyed by `system.theme.name`.
#
# Every set defines the same 26 role names — catppuccin's vocabulary — so a
# consumer reads `palette.mauve` without knowing which set is active. The
# vocabulary is catppuccin's because serpantinum's QML defines those 26 names
# as colour properties and 98 of its files read them; anything else would be a
# translation layer rather than a palette.
#
# Imported by both `nixosModules/themes/stylix.nix` (for base16) and
# `users/hailst0rm/homeManagerModules/palette.nix` (for the widget colours),
# which is why it lives in `lib/` rather than either auto-imported directory.
{lib}: let
  catppuccin-mocha = {
    rosewater = "#f5e0dc";
    flamingo = "#f2cdcd";
    pink = "#f5c2e7";
    mauve = "#cba6f7";
    red = "#f38ba8";
    maroon = "#eba0ac";
    peach = "#fab387";
    yellow = "#f9e2af";
    green = "#a6e3a1";
    teal = "#94e2d5";
    sky = "#89dceb";
    sapphire = "#74c7ec";
    blue = "#89b4fa";
    lavender = "#b4befe";
    text = "#cdd6f4";
    subtext1 = "#bac2de";
    subtext0 = "#a6adc8";
    overlay2 = "#9399b2";
    overlay1 = "#7f849c";
    overlay0 = "#6c7086";
    surface2 = "#585b70";
    surface1 = "#45475a";
    surface0 = "#313244";
    base = "#1e1e2e";
    mantle = "#181825";
    crust = "#11111b";
  };

  # A cold single-hue depth ramp lit by one warm accent.
  #
  # Every value is a token from the styleguide's `styleguide/tokens.css`; that
  # file is the only place a colour is born, so a role that needs a shade the
  # styleguide lacks gets remapped onto an existing token, never a new hex.
  # The twelve neutrals come from its two same-hue ramps: navy runs out between
  # L34 and L43, which is where catppuccin puts its overlays, so overlay0-2
  # come from the paper ramp's dark end.
  #
  #   crust/mantle/base  navy-950/900/800   surface0  navy-700  --surface-selected
  #   surface1  navy-600 --border           surface2  paper-800 (== overlay0)
  #   overlay0-2  paper-800/700/600         subtext0/1  navy-400/300 --text-muted/-secondary
  #   text  navy-100 --text
  #
  # surface0 must skip navy-750: that token is `--border-subtle`, one L step off
  # navy-800, so using it as a fill made every card, toggle and progress track
  # sit at 1.02 contrast against the panel behind it. navy-700 is the token for
  # a raised or selected surface and lands at 1.16. The styleguide's dark ramp
  # is deliberately flat here and pairs it with a 1px hairline in the next step
  # up rather than a bigger fill jump, which is what swaync.nix already draws.
  # That leaves surface2 sharing paper-800 with overlay0 — the only alternative
  # is navy-600, already taken by surface1.
  #
  # `peach` is amber-400, the styleguide's single accent.
  navy = {
    rosewater = "#FBE2EA";
    flamingo = "#E7B3C6";
    pink = "#DF99B4";
    mauve = "#B0A8E4";
    red = "#EF7D88";
    maroon = "#EBA0A5";
    peach = "#F2A529";
    yellow = "#DBC63F";
    green = "#8ACA8B";
    teal = "#6BC3BD";
    sky = "#93C2BE";
    sapphire = "#A0C8F4";
    blue = "#77BFF9";
    lavender = "#C3BEE9";
    text = "#E3E9ED";
    subtext1 = "#AAB6C0";
    subtext0 = "#7E8E9E";
    overlay2 = "#738598";
    overlay1 = "#5C6874";
    overlay0 = "#44515F";
    surface2 = "#44515F";
    surface1 = "#283A4C";
    surface0 = "#1D2A38";
    base = "#101E2D";
    mantle = "#07121F";
    crust = "#040913";
  };

  sets = {
    inherit catppuccin-mocha navy;
  };
in
  assert lib.assertMsg
  (lib.attrNames catppuccin-mocha == lib.attrNames navy)
  ''
    lib/palettes.nix: the colour sets define different role names.
    Only in catppuccin-mocha: ${
      lib.concatStringsSep " " (lib.subtractLists (lib.attrNames navy) (lib.attrNames catppuccin-mocha))
    }
    Only in navy: ${
      lib.concatStringsSep " " (lib.subtractLists (lib.attrNames catppuccin-mocha) (lib.attrNames navy))
    }
  ''; {
    inherit sets;

    # Schemes we define ourselves. Everything else — including catppuccin-mocha,
    # whose widget set above exists only so `palette` resolves on those hosts —
    # keeps coming from `pkgs.base16-schemes`, so unswitched hosts are untouched.
    local = ["navy"];

    # Any other base16 scheme name keeps catppuccin's widget colours; stylix
    # still themes everything it owns from that scheme's own yaml.
    forTheme = name: sets.${name} or catppuccin-mocha;

    # Slot for slot the same mapping base16-schemes uses for catppuccin-mocha,
    # so every stylix target behaves identically whichever scheme is active.
    # base16 strips the leading `#` itself.
    base16 = p: {
      base00 = p.base;
      base01 = p.surface0;
      base02 = p.surface1;
      base03 = p.overlay0;
      base04 = p.subtext0;
      base05 = p.text;
      base06 = p.rosewater;
      base07 = p.lavender;
      base08 = p.red;
      base09 = p.peach;
      base0A = p.yellow;
      base0B = p.green;
      base0C = p.teal;
      base0D = p.blue;
      base0E = p.mauve;
      base0F = p.flamingo;
    };
  }
