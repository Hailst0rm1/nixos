{
  config,
  pkgs,
  lib,
  ...
}: let
  ghost = config.services.ghost;
  domainUnderscore = builtins.replaceStrings ["."] ["_"] ghost.domain;
  dataDir = "/var/www/${domainUnderscore}";
  mysqlData = "/var/lib/mysql-ghost";

  port = "2368";
in
  with lib; {
    options.services.ghost = {
      enable = mkEnableOption "Enable ghost blog service.";

      domain = mkOption {
        type = types.str;
        default = "";
        description = "Domain user for ghost, e.g. example.com";
      };

      sslCertPath = mkOption {
        type = types.str;
        description = "The ssl cert.pem file path.";
      };

      sslCertKeyPath = mkOption {
        type = types.str;
        description = "The ssl private key cert.key file path.";
      };
    };

    config = mkIf ghost.enable {
      virtualisation.oci-containers.containers = {
        db = {
          image = "mysql:8.0";
          autoStart = true;
          environment = {
            MYSQL_ROOT_PASSWORD = "example"; # Use a secure secret in production
          };
          volumes = [
            "${mysqlData}:/var/lib/mysql"
          ];
        };

        ghost = {
          image = "ghost:latest";
          autoStart = true;
          ports = [
            "127.0.0.1:${port}:2368"
          ];
          environment = {
            url = "http://localhost:${port}";
            database__client = "mysql";
            database__connection__host = "db"; # name of the mysql container
            database__connection__user = "root";
            database__connection__password = "example";
            database__connection__database = "ghost";
          };
          volumes = [
            "${dataDir}:/var/lib/ghost/content"
          ];
        };
      };

      systemd.tmpfiles.rules = [
        "d ${dataDir} 0755 ghost ghost - -"
      ];

      users.users.ghost = {
        isSystemUser = true;
        group = "ghost";
      };
      users.groups.ghost = {};

      environment.etc."${domainUnderscore}-ghost.json".text = ''
        {
          "url": "https://${ghost.domain}",
          "server": {
            "port": 2369,
            "host": "127.0.0.1"
          },
          "database": {
            "client": "mysql",
            "connection": {
              "host": "localhost",
              "user": "ghost",
              "password": "",
              "database": "${domainUnderscore}"
            }
          },
          "admin": {
            "url": "https://admin.${ghost.domain}"
          },
          "logging": {
            "transports": [
              "file",
              "stdout"
            ]
          },
          "process": "systemd",
          "paths": {
            "contentPath": "${dataDir}/content"
          }
        }
      '';

      # Optional: firewall rule or Nginx reverse proxy could go here

      # Sets up the Nginx web proxy
      services.nginx = {
        enable = true;
        # recommendedGzipSettings = true;
        # recommendedOptimisation = true;
        # recommendedProxySettings = true;
        # recommendedTlsSettings = true;
        virtualHosts."${ghost.domain}" = {
          enableACME = false;
          forceSSL = true;
          http2 = true;

          sslCertificate = ghost.sslCertPath;
          sslCertificateKey = ghost.sslCertKeyPath;

          root = "${dataDir}/system/nginx-root";

          extraConfig = ''
            client_max_body_size 100m;
          '';

          locations."/" = {
            proxyPass = "http://127.0.0.1:2369";
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
