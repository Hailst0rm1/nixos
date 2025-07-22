{
  config,
  pkgs,
  lib,
  ...
}: let
  # TODO: password in sops that isn't accessed in /run (?)# TODO: password in sops that isn't accessed in /run (?)
  ghost = config.services.ghost;
  domainUnderscore = builtins.replaceStrings ["."] ["_"] domain;
  dataDir = "/var/lib/ghost/content";
  domain = config.services.domain;

  port = "2368";
in
  with lib; {
    options.services.ghost = {
      enable = mkEnableOption "Enable ghost blog service.";
      sslCertFile = mkOption {
        type = types.str;
        description = "The ssl cert.pem file path.";
      };

      sslCertKeyFile = mkOption {
        type = types.str;
        description = "The ssl private key cert.key file path.";
      };
    };

    config = mkIf ghost.enable {
      networking.firewall.allowedTCPPorts = [80 443];

      users.users.ghost = {
        isSystemUser = true;
        group = "ghost";
      };
      users.groups.ghost = {};

      virtualisation.oci-containers.containers = {
        ghost = {
          image = "ghost:latest";
          autoStart = true;
          ports = [
            "${port}:2368"
          ];
          extraOptions = ["--network=host"];
          environment = {
            url = "https://${domain}";
            admin__url = "https://admin.${domain}";
            database__client = "mysql";
            database__connection__host = "127.0.0.1";
            database__connection__user = "ghost";
            database__connection__password = "Wheat%Sedation%Rebalance9";
            database__connection__database = domainUnderscore;
            # mail__from = "noreply@mail.${domain}";
            # # mail__from = "Ponton Security <noreply@mail.${domain}>";
            # mail__transport = "SMTP";
            # mail__options__service = "Mailgun";
            # mail__options__host = "smtp.eu.mailgun.org";
            # mail__options__port = "465";
            # mail__options__secure = "true";
            # mail__options__auth__user = "noreply@mail.${domain}";
            # mail__options__auth__pass = "";
          };
          volumes = [
            "${dataDir}:/var/lib/ghost/content"
          ];
        };
      };

      # Create dataDir directory
      systemd.tmpfiles.rules = [
        "d ${dataDir} 0755 ghost ghost - -"
      ];

      services.mysql = {
        enable = true;
        package = pkgs.mysql80;
        initialScript = pkgs.writeText "mysql-init.sql" ''
          CREATE DATABASE IF NOT EXISTS ${domainUnderscore};
          CREATE USER IF NOT EXISTS 'ghost'@'localhost' IDENTIFIED BY 'Wheat%Sedation%Rebalance9';
          GRANT ALL PRIVILEGES ON ${domainUnderscore}.* TO 'ghost'@'localhost';
          FLUSH PRIVILEGES;
        '';
        settings = {
          mysqld = {
            bind-address = "127.0.0.1"; # only accessible locally
          };
        };
      };

      # Sets up the Nginx web proxy
      services.nginx = {
        enable = true;
        # recommendedGzipSettings = true;
        # recommendedOptimisation = true;
        # recommendedProxySettings = true;
        # recommendedTlsSettings = true;
        virtualHosts."${domain}" = {
          enableACME = false;
          forceSSL = true;
          http2 = true;

          sslCertificate = ghost.sslCertFile;
          sslCertificateKey = ghost.sslCertKeyFile;

          root = "${dataDir}/system/nginx-root";

          serverAliases = ["*.${domain}"];

          extraConfig = ''
            client_max_body_size 100m;
          '';

          locations."/" = {
            proxyPass = "http://127.0.0.1:${port}";
            extraConfig = ''
              proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
              proxy_set_header X-Forwarded-Proto $scheme;
              proxy_set_header X-Real-IP $remote_addr;
              proxy_set_header Host $host;

              if ($request_method = 'OPTIONS') {
                add_header 'Access-Control-Allow-Origin' '*' always;
                add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS';
                add_header 'Access-Control-Allow-Headers' 'Accept-Version,Credentials,Authorization,DNT,Mode,User-Agent,x-ghost-preview,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range';
                add_header 'Access-Control-Max-Age' 1728000;
                add_header 'Content-Type' 'text/plain; charset=utf-8';
                add_header 'Content-Length' 0;
                return 204;
              }
              if ($request_method = 'POST') {
                add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS' always;
                add_header 'Access-Control-Allow-Headers' 'Authorization,Credentials,DNT,Mode,User-Agent,x-ghost-preview,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range' always;
                add_header 'Access-Control-Expose-Headers' 'Content-Length,Content-Range' always;
              }
              if ($request_method = 'GET') {
                add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS' always;
                add_header 'Access-Control-Allow-Headers' 'Authorization,Credentials,DNT,Mode,User-Agent,X-Requested-With,x-ghost-preview,If-Modified-Since,Cache-Control,Content-Type,Range' always;
                add_header 'Access-Control-Expose-Headers' 'Content-Length,Content-Range' always;
              }
              if ($http_origin = "app://obsidian.md") {
                add_header 'Access-Control-Allow-Origin' '*' always;
              }
            '';
          };

          locations."~ /.well-known" = {
            extraConfig = "allow all;";
          };
        };
      };
    };
  }
