{ pkgs, config, lib, ... }:
let
  cfg = config.desktopEnvironment.displayManager;
in {
  config = lib.mkIf (cfg.enable && cfg.name == "sddm") {
    environment.systemPackages = [
      (pkgs.catppuccin-sddm.override {
        flavor = "mocha";
        font  = "Rubik";
        fontSize = "9";
        background = "${../wallpapers/mountain.jpg}";
        loginBackground = true;
      })
    ];

    services.displayManager.sddm = {
      enable = true;
      theme = "catppuccin-mocha";
      wayland.enable = true;
      package = pkgs.kdePackages.sddm;
      settings = {
        Users = {
          HideShells = "/usr/bin/nologin,/sbin/nologin";
        };
      };
    };
  };
}
