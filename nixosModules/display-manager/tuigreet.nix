{
  pkgs,
  lib,
  config,
  ...
}:
# Enable Display Manager
#services.displayManager.sddm = {
# enable = true;
# };
let
  tuigreet = "${pkgs.greetd.tuigreet}/bin/tuigreet";
  cfg = config.desktopEnvironment.displayManager;
in {
  config = lib.mkIf (cfg.enable && cfg.name == "tuigreep") {
    services.greetd = {
      enable = true;
      settings = {
        initial_session = {
          command = "${config.desktopEnvironment.name}";
          user = "${config.username}";
        };
        default_session = {
          command = "${tuigreet} --greeting 'Welcome to NixOS!' --asterisks --remember --remember-user-session --time --cmd ${config.desktopEnvironment.name}";
          user = "greeter";
        };
      };
    };
  };
}
