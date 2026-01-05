{
  inputs,
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.system.theme;
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
      base16Scheme = "${pkgs.base16-schemes}/share/themes/${cfg.name}.yaml";
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
        serif = {
          package = pkgs.noto-fonts;
          name = "Noto Serif";
        };

        sansSerif = {
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
