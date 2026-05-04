{
  config,
  lib,
  ...
}: let
  cfg = config.services.n8n.podman;
in {
  options.services.n8n.podman = {
    enable = lib.mkEnableOption "n8n workflow automation via Podman container";
    host = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "Address n8n listens on.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 5678;
      description = "Port n8n listens on.";
    };
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/n8n";
      description = "Persistent data directory.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.n8n = {
      image = "n8nio/n8n:2.15.0";
      extraOptions = ["--network=host"];
      volumes = ["${cfg.dataDir}:/home/node/.n8n"];
      environment = {
        GENERIC_TIMEZONE = config.time.timeZone;
        N8N_HOST = cfg.host;
        N8N_PORT = toString cfg.port;
        N8N_DIAGNOSTICS_ENABLED = "false";
        N8N_VERSION_NOTIFICATIONS_ENABLED = "false";
        NOTEBOOKLM_BRIDGE_URL = "http://127.0.0.1:9090";
      };
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 1000 1000 -"
    ];
  };
}
