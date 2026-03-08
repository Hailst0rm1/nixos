{
  config,
  lib,
  pkgs,
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
        "9b5db6b1-0e86-4c6d-b6cc-15b7e375c39b" = {
          credentialsFile = "${config.sops.secrets."services/cloudflared/creds".path}";
          default = "http_status:404";
        };
      };
    };

    services.cloudflare-warp = {
      enable = true;
      package = pkgs-unstable.cloudflare-warp;
    };

    environment.systemPackages = [pkgs-unstable.cloudflared pkgs-unstable.cloudflare-warp];
  };
}
