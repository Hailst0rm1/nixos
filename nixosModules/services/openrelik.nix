{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.openrelik;
  stateDir = "/var/lib/openrelik";
  docker = config.virtualisation.docker.package;

  # Version of the openrelik-server/UI images; selects config_<v>.env and
  # docker-compose_<v>.yml in openrelik-deploy and the server's settings template.
  openrelikRelease = "0.7.0";

  # What docker/install.sh downloads from openrelik-deploy main.
  deploy = pkgs.fetchFromGitHub {
    owner = "openrelik";
    repo = "openrelik-deploy";
    # track-branch: main
    rev = "f44ed1f191945d77ab8d8d2d4704db95856e0edd";
    hash = "sha256-9HYzjX1f9QKCf9YeBb0ZA9l/SykCMh7s92wqjjbo9jE=";
  };
  settingsExample = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/openrelik/openrelik-server/refs/tags/${openrelikRelease}/settings_example.toml";
    hash = "sha256-/+elWD3u55IVfEvqkWdZXVns8wIMXrWsIIXPAacEJZ0=";
  };
in {
  options.services.openrelik.enable = lib.mkEnableOption ''
    OpenRelik forensic workflow platform (Docker Compose stack).
    The UI listens on http://127.0.0.1:8711 and the API on 127.0.0.1:8710
    (hardcoded loopback in upstream's compose file). The `admin` password is
    written to /var/lib/openrelik/admin-password on first start
  '';

  config = lib.mkIf cfg.enable {
    # The compose stack runs against a system daemon; the repo's default docker
    # host is rootless and per-user.
    virtualisation.docker.enable = lib.mkDefault true;

    systemd.services.openrelik = {
      description = "OpenRelik (Docker Compose)";
      wantedBy = ["multi-user.target"];
      after = ["docker.service" "network-online.target"];
      requires = ["docker.service"];
      wants = ["network-online.target"];
      path = [docker pkgs.openssl pkgs.coreutils pkgs.gnused pkgs.gnugrep];
      environment.DOCKER_HOST = "unix:///var/run/docker.sock";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        WorkingDirectory = stateDir;
        StateDirectory = "openrelik";
        StateDirectoryMode = "0700";
        TimeoutStartSec = "15min"; # first start pulls the images
        ExecStart = "${docker}/bin/docker compose up -d --wait --remove-orphans";
        # Schema migration is idempotent; admin user is created once.
        ExecStartPost = pkgs.writeShellScript "openrelik-init" ''
          set -eu
          docker=${docker}/bin/docker
          $docker compose exec -T openrelik-server bash -c "cd /app/openrelik/datastores/sql && alembic upgrade head"
          if [ ! -e admin-password ]; then
            umask 077
            openssl rand -hex 12 > admin-password
            $docker compose exec -T openrelik-server python admin.py create-user admin --password "$(cat admin-password)" --admin
          fi
        '';
        ExecStop = "${docker}/bin/docker compose down";
      };
      preStart = ''
        umask 077
        mkdir -p data/postgresql data/artifacts data/prometheus config/prometheus

        for s in postgres_password session_key jwt_key; do
          [ -e $s ] || openssl rand -hex 16 > $s
        done

        install -m644 ${deploy}/docker/docker-compose_${openrelikRelease}.yml docker-compose.yml
        install -m644 ${deploy}/docker/prometheus.yml config/prometheus/prometheus.yml

        # Same substitutions as docker/install.sh.
        sed \
          -e 's#<REPLACE_WITH_STORAGE_PATH>#/usr/share/openrelik/data/artifacts#' \
          -e 's#<REPLACE_WITH_POSTGRES_USER>#openrelik#' \
          -e "s#<REPLACE_WITH_POSTGRES_PASSWORD>#$(cat postgres_password)#" \
          -e 's#<REPLACE_WITH_POSTGRES_SERVER>#openrelik-postgres#' \
          -e 's#<REPLACE_WITH_POSTGRES_DATABASE_NAME>#openrelik#' \
          -e "s#<REPLACE_WITH_RANDOM_SESSION_STRING>#$(cat session_key)#" \
          -e "s#<REPLACE_WITH_RANDOM_JWT_STRING>#$(cat jwt_key)#" \
          ${settingsExample} > config/settings.toml
        sed \
          -e 's#<REPLACE_WITH_POSTGRES_USER>#openrelik#' \
          -e "s#<REPLACE_WITH_POSTGRES_PASSWORD>#$(cat postgres_password)#" \
          -e 's#<REPLACE_WITH_POSTGRES_DATABASE_NAME>#openrelik#' \
          ${deploy}/docker/config_${openrelikRelease}.env > .env

        # <REPLACE_WITH_USERNAME> belongs to the unused [auth.google] allowlist.
        if grep -E '<REPLACE_WITH_' config/settings.toml .env | grep -v '<REPLACE_WITH_USERNAME>'; then
          echo "openrelik placeholders not substituted; upstream template changed" >&2
          exit 1
        fi
      '';
    };
  };
}
