{
  config,
  lib,
  pkgs-unstable,
  ...
}: {
  options.services.gitlab = {
    serverIp = lib.mkOption {
      type = lib.types.str;
      description = "Will set git.<domain> to serverIp for ssh connection.";
    };
  };

  config = {
    # WARNING: DOESN'T WORK BECAUSE OF SOME POSTGRES STUFF
    services.gitlab = lib.mkIf config.services.gitlab.enable {
      host = "gitlab.${config.services.domain}";
      port = 443;
      https = true;
      user = "git";
      group = "git";
      databaseUsername = "git";
    };

    services.nginx.virtualHosts."gitlab.${config.services.domain}" = lib.mkIf config.services.gitlab.enable {
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

    services.postgresql = lib.mkIf config.services.gitlab.enable {
      enable = true;
      package = pkgs-unstable.postgresql_18;
    };

    systemd.services.gitlab-backup.environment.BACKUP = lib.mkIf config.services.gitlab.enable "dump";

    networking.extraHosts = ''
      ${config.services.tailscaleAutoconnect.exitNode} git.${config.services.domain}
    '';
  };
}
