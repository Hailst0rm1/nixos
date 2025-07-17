{
  config,
  lib,
  pkgs-unstable,
  ...
}: let
  cfg = config.services.cloudflared;
in {
  config = lib.mkIf cfg.enable {
    services.cloudflared = {
      tunnels = {
        "7a34e024-e936-477f-9a0e-e8e3624ee2a0" = {
          credentialsFile = "${config.sops.secrets."services/cloudflared/creds".path}";
          default = "http_status:404";
        };
      };
    };

    environment.systemPackages = [pkgs-unstable.cloudflared];
  };
}
