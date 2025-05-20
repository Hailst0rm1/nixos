{ lib, config, pkgs, ... }: {
  config = lib.mkIf config.importConfig.hyprland.enable {
    gtk = {
      enable = true;
      iconTheme.name = "Papirus-Dark";
      iconTheme.package = pkgs.catppuccin-papirus-folders.override {
        flavor = "mocha";
        accent = "blue";
      };
    };
  };
}
