{
  config,
  lib,
  ...
}: let
  cfg = config.desktopEnvironment.name;
in {
  config = lib.mkIf (cfg == "gnome") {
    services.xserver = {
      enable = true;
      desktopManager.gnome.enable = true;
      displayManager.gdm.enable = true;
    };

    # Disable power settings for screen as default
    systemd = {
      targets = {
        sleep.enable = false;
        suspend.enable = false;
        hibernate.enable = false;
        hybrid-sleep.enable = false;
      };
    };
  };
}
