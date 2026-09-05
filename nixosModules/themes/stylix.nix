{
  inputs,
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.system.theme;

  palettes = import ../../lib/palettes.nix {inherit lib;};
  isLocalScheme = lib.elem cfg.name palettes.local;

  # Archivo (display) and Public Sans (body) ship only as Google Fonts.
  styleguideFonts = pkgs.google-fonts.override {
    fonts = ["Archivo" "Public Sans"];
  };
in {
  imports = [
    inputs.stylix.nixosModules.stylix
    # inputs.stylix.homeModules.stylix
  ];

  options.system.theme = {
    enable = lib.mkEnableOption "Enable stylix.";
    name = lib.mkOption {
      type = lib.types.str;
      default = "catppuccin-mocha";
      description = "Choose stylix theme.";
    };
    polarity = lib.mkOption {
      type = lib.types.str;
      default = "dark";
      description = "Dark or light theme.";
    };
  };

  config = {
    stylix = {
      enable = true;
      autoEnable = cfg.enable;
      # Schemes we define ourselves come from lib/palettes.nix; every other
      # name is still a base16-schemes filename, as it always was.
      base16Scheme =
        if isLocalScheme
        then
          palettes.base16 palettes.sets.${cfg.name}
          // {
            scheme = cfg.name;
            author = "hailst0rm";
            variant = cfg.polarity;
            slug = cfg.name;
          }
        else "${pkgs.base16-schemes}/share/themes/${cfg.name}.yaml";
      image = ../../assets/images/nixos-logos.png;
      polarity = "${cfg.polarity}";

      cursor = lib.mkIf cfg.enable {
        package = pkgs.bibata-cursors;
        name = "Bibata-Modern-Ice";
        size = 24;
      };

      targets = lib.mkIf cfg.enable {
        grub.useWallpaper = true;
      };

      fonts = lib.mkIf cfg.enable {
        # The navy scheme brings the styleguide's own faces with it. Monospace
        # stays JetBrainsMono: the styleguide's mono has no Nerd Font build,
        # and the bar, prompt and file manager are full of NF glyphs.
        serif =
          if cfg.name == "navy"
          then {
            package = styleguideFonts;
            name = "Archivo";
          }
          else {
            package = pkgs.noto-fonts;
            name = "Noto Serif";
          };

        sansSerif =
          if cfg.name == "navy"
          then {
            package = styleguideFonts;
            name = "Public Sans";
          }
          else {
            package = pkgs.rubik;
            name = "Rubik";
          };

        monospace = {
          package = pkgs.nerd-fonts.jetbrains-mono;
          name = "JetBrainsMono Nerd Font Mono";
        };

        emoji = {
          package = pkgs.noto-fonts-color-emoji;
          name = "Noto Color Emoji";
        };
      };
    };
  };
}
