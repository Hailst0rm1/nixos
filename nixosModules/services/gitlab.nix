{
  config,
  lib,
  pkgs-unstable,
  ...
}: let
  enabled = config.services.gitlab.enable;
in
  lib.mkIf enabled {
    services.gitlab = {
      host = "git.${config.services.domain}";
      port = 443;
      https = true;
      user = "git";
      group = "git";
      databaseUsername = "git";
    };

    services.nginx.virtualHosts."git.${config.services.domain}" = {
      enableACME = false;
      forceSSL = false;
      listen = [
        {
          addr = "127.0.0.1";
          port = 8080;
        }
      ];

      locations."/" = {
        proxyPass = "http://unix:/run/gitlab/gitlab-workhorse.socket";
        proxyWebsockets = true;

        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto https;
        '';
      };
    };

    services.postgresql = {
      enable = true;
      package = pkgs-unstable.postgresql_18;
    };

    systemd.services.gitlab-backup.environment.BACKUP = "dump";
  }
