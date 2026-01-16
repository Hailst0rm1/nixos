{
  config,
  lib,
  pkgs-unstable,
  ...
}: {
  config = lib.mkIf (config.services.code-server.enable or config.services.openvscode-server.enable) {
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
    services.openvscode-server = {
      package = pkgs-unstable.openvscode-server;
      user = config.username or "hailst0rm";
      group = "users";
      host = "127.0.0.1";
      port = lib.mkDefault 8443;
      # auth = "none";
      # disableTelemetry = true;
      # disableUpdateCheck = true;
      # disableWorkspaceTrust = true;
    };
    environment.systemPackages = with pkgs-unstable; [code-server openvscode-server];
  };
}
