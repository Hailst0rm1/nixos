{
  config,
  lib,
  ...
}: let
  cfg = config.services.rsshub;
in {
  options.services.rsshub = {
    enable = lib.mkEnableOption "RSSHub self-hosted RSS feed generator";
    port = lib.mkOption {
      type = lib.types.port;
      default = 1200;
      description = "Port RSSHub listens on.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.rsshub = {
      image = "diygod/rsshub:latest";
      extraOptions = ["--network=host"];
      environment = {
        PORT = toString cfg.port;
      };
    };
  };
}
