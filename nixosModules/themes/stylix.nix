{
  inputs,
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.system.theme;
in {
  #imports = lib.optionals cfg.enable [ inputs.stylix.nixosModules.stylix ];
  imports = [inputs.stylix.nixosModules.stylix];

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

  config = lib.mkIf cfg.enable {
    stylix = {
      enable = true;
      base16Scheme = "${pkgs.base16-schemes}/share/themes/${cfg.name}.yaml";
      image = ../wallpapers/nixos-logos.png;
      polarity = "${cfg.polarity}";
      # opacity = {
      #   applications = lib.mkForce 0.5;
      #   desktop = lib.mkForce 0.5;
      #   popups = lib.mkForce 0.5;
      #   terminal = lib.mkForce 0.2;
      # };

      cursor = {
        package = pkgs.bibata-cursors;
        name = "Bibata-Modern-Ice";
        size = 24;
      };

      targets = {
        grub.useImage = true;
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
          package = pkgs.nerd-fonts.jetbrains-mono;
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
