{
  config,
  lib,
  pkgs-unstable,
  ...
}: {
  options.services.cloudflare = {
    enable = lib.mkEnableOption "Enable cloudflare tunneling.";
    deviceType = lib.mkOption {
      type = lib.types.enum [
        "client"
        "server"
      ];
      description = "Whether the cloudflare connected device is a client or a server.";
    };
  };

  config = lib.mkIf config.services.cloudflare.enable {
    services.cloudflared = lib.mkIf (config.services.cloudflare.deviceType == "server") {
      enable = true;
      tunnels = {
        "7a34e024-e936-477f-9a0e-e8e3624ee2a0" = {
          credentialsFile = "${config.sops.secrets."services/cloudflared/creds".path}";
          default = "http_status:404";
        };
      };
    };

    services.cloudflare-warp.enable = true;

    environment.systemPackages = [pkgs-unstable.cloudflared pkgs-unstable.cloudflare-warp];
  };
}
