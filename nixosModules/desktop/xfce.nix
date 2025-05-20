{
  config,
  lib,
  ...
}: let
  cfg = config.desktopEnvironment.name;
in {
  config = lib.mkIf (cfg == "xfce") {
    nixpkgs.config.pulseaudio = true;

    services.xserver = {
      enable = true;
      desktopManager = {
        xterm.enable = false;
        xfce.enable = true;
      };
      displayManager.defaultSession = "xfce";
    };
  };
}
