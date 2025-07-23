{
  config,
  lib,
  pkgs,
  ...
}: {
  options.services.vaultwarden = with lib; {
    adminToken = mkOption {
      type = types.str;
      default = "";
      description = "Token for admin panel `/admin`. Generate with `vaultwarden hash`.";
    };
    allowSignup = mkEnableOption "Allow signing up new users";
    yubicoClient = mkOption {
      type = types.str;
      default = "";
      description = "Client ID: Setup yubico api-key https://upgrade.yubico.com/getapikey/";
    };
    yubicoKey = mkOption {
      type = types.str;
      default = "";
      description = "Secret Key: Setup yubico api-key https://upgrade.yubico.com/getapikey/";
    };
  };

  config = lib.mkIf config.services.vaultwarden.enable {
    services.vaultwarden = {
      config = {
        ROCKET_ADDRESS = "127.0.0.1";
        ROCKET_PORT = 8222;
        DOMAIN = "https://vault.${config.services.domain}";
        ADMIN_TOKEN = config.services.vaultwarden.adminToken;
        SIGNUPS_ALLOWED = config.services.vaultwarden.allowSignup;
        YUBICO_CLIENT = config.services.vaultwarden.yubicoClient;
        YUBICO_SECRET_KEY = config.services.vaultwarden.yubicoKey;
        EXTENDED_LOGGING = true;
        LOG_LEVEL = "warn";
        IP_HEADER = "CF-Connecting-IP";
      };
    };
    environment.systemPackages = [
      pkgs.vaultwarden
    ];
  };
}
