{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.desktopEnvironment.displayManager;
in {
  config = lib.mkIf (cfg.enable && cfg.name == "gdm") {
    services.xserver = {
      enable = true;
      displayManager = {
        gdm.enable = lib.mkDefault true;
      };
    };
  };
}

