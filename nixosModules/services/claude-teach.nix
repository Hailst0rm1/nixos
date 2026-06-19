{
  config,
  lib,
  ...
}: let
  cfg = config.services.claudeTeach;
in {
  options.services.claudeTeach = with lib; {
    enable = mkEnableOption "Serve HTML lessons from a directory over HTTP (Tailscale-only)";

    root = mkOption {
      type = types.str;
      default = "/mnt/nas/claude-teach";
      description = "Directory of HTML lesson folders to serve. Browsable index at the root URL.";
    };

    port = mkOption {
      type = types.port;
      default = 8088;
      description = ''
        TCP port nginx listens on. Reachable over Tailscale only — the port is
        intentionally NOT added to the public firewall. tailscale0 is a trusted
        interface (see services/tailscale.nix), so the tailnet can reach it
        while LAN and public traffic are blocked.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.nginx = {
      enable = true;
      virtualHosts."claude-teach" = {
        listen = [
          {
            addr = "0.0.0.0";
            port = cfg.port;
            extraParameters = ["default_server"];
          }
        ];
        root = cfg.root;
        locations."/" = {
          extraConfig = ''
            autoindex on;
          '';
        };
      };
    };
  };
}
