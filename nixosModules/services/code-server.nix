{
  config,
  lib,
  pkgs-unstable,
  ...
}: let
  cfg = config.services.code-server;
in {
  config = lib.mkIf cfg.enable {
    services.code-server = {
      package = pkgs-unstable.code-server;
      user = config.username or "hailst0rm";
      group = "users";
      host = "127.0.0.1";
      port = lib.mkDefault 8443;
      auth = "none";
      # disableTelemetry = true;
      disableUpdateCheck = true;
      disableWorkspaceTrust = true;
    };
  };
}
