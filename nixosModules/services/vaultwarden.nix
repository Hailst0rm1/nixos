{
  config,
  lib,
  pkgs,
  ...
}: {
  options.services.vaultwarden = with lib; {
    domain = mkOption {
      type = types.str;
      default = "";
      description = "Domain user for ghost, e.g. example.com";
    };
  };

  config.services.vaultwarden = lib.mkIf config.services.vaultwarden.enable {
    config = {
      DOMAIN = "https://vault.${config.services.vaultwarden.domain}";
      SIGNUPS_ALLOWED = false;
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = 8222;
      EXTENDED_LOGGING = true;
      LOG_LEVEL = "warn";
      IP_HEADER = "CF-Connecting-IP";
    };
  };
}
