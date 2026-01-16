{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}: {
  config = lib.mkIf (config.services.code-server.enable || config.services.openvscode-server.enable) {
    services.code-server = lib.mkIf config.services.code-server.enable {
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

    services.openvscode-server = lib.mkIf config.services.openvscode-server.enable {
      package = pkgs.openvscode-server; # Use stable - unstable is broken
      user = config.username or "hailst0rm";
      group = "users";
      host = "127.0.0.1";
      port = lib.mkDefault 8443;
      withoutConnectionToken = true; # Allow access without token - only safe if behind another auth layer
    };

    # Enable direnv
    programs.direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };

    environment.systemPackages =
      lib.optionals (config.services.code-server.enable || config.services.openvscode-server.enable)
      [pkgs-unstable.code-server pkgs.openvscode-server];
  };
}
