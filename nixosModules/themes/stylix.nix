{
  inputs,
  pkgs,
  config,
  lib,
  ...
}:
let
  cfg = config.system;
in {
  options.system = {
    theme = lib.mkOption = {
      type = lib.types.str;
      default = null;
      description = "Choose stylix theme.";
    };
    polarity = lib.mkOption = {
      type = lib.types.str;
      default = "dark";
      description = "Dark or light theme.";
    };
  };

  config = lib.mkIf (cfg.theme != null) {

    imports = [inputs.stylix.nixosModules.stylix];
    stylix = {
      enable = true;
      base16Scheme = "${pkgs.base16-schemes}/share/themes/${cfg.theme}.yaml";
      image = ../wallpapers/nixos-logos.png;
      polarity = "${cfg.polarity}";
      opacity = {
        terminal = 0.9;
        desktop = 0.9;
      };

      cursor = {
        package = pkgs.bibata-cursors;
        name = "Bibata-Modern-Ice";
        size = 24;
      };

      fonts = {
        serif = {
          package = pkgs.noto-fonts;
          name = "Noto Serif";
        };

        sansSerif = {
          package = pkgs.rubik;
          name = "Rubik";
        };

        monospace = {
          package = pkgs.nerdfonts.override {fonts = ["JetBrainsMono"];};
          name = "JetBrainsMono Nerd Font Mono";
        };

        emoji = {
          package = pkgs.noto-fonts-emoji;
          name = "Noto Color Emoji";
        };
      };
    };
  };
}
