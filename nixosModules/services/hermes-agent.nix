{
  config,
  lib,
  ...
}: let
  cfg = config.services.hermes-agent;
in {
  options.services.hermes-agent = {
    enable = lib.mkEnableOption "Hermes Agent self-improving AI agent by Nous Research";
    port = lib.mkOption {
      type = lib.types.port;
      default = 8333;
      description = "Port Hermes Agent listens on.";
    };
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/hermes-agent";
      description = "Persistent data directory.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.hermes-agent = {
      image = "nousresearch/hermes-agent:latest";
      extraOptions = ["--network=host"];
      volumes = ["${cfg.dataDir}:/opt/data"];
      environment = {
        PORT = toString cfg.port;
      };
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 1000 1000 -"
    ];
  };
}
