{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.timesketch;
  stateDir = "/var/lib/timesketch";
  docker = config.virtualisation.docker.package;

  # Upstream's docker/release compose stack and config templates, pinned to a
  # release tag (what contrib/deploy_timesketch.sh downloads from master).
  timesketchRelease = "20260630";
  src = pkgs.fetchFromGitHub {
    owner = "google";
    repo = "timesketch";
    rev = timesketchRelease;
    hash = "sha256-O0WoZbdqnsqyHrSGCgT27pfTaVsBfGXkvNdo4FKFdpw=";
  };

  dataFiles = [
    "tags.yaml"
    "plaso.mappings"
    "generic.mappings"
    "regex_features.yaml"
    "winevt_features.yaml"
    "ontology.yaml"
    "intelligence_tag_metadata.yaml"
    "sigma_config.yaml"
    "sigma/rules/lnx_susp_zmap.yml"
    "plaso_formatters.yaml"
    "context_links.yaml"
    "llm_summarize/prompt.txt"
    "llm_starred_events_report/prompt.txt"
    "nl2q/data_types.csv"
    "nl2q/prompt_nl2q"
    "nl2q/examples_nl2q"
  ];
in {
  options.services.timesketch = {
    enable = lib.mkEnableOption "Timesketch collaborative forensic timeline analysis (Docker Compose stack)";

    bindAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = ''
        Address the web UI is published on. Docker publishes ports straight
        through iptables, bypassing the NixOS firewall, so keep this on
        loopback unless something in front of it handles TLS and access.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 5000;
      description = "Port of the web UI (plain http, served by the nginx container).";
    };

    opensearchMemoryGb = lib.mkOption {
      type = lib.types.ints.positive;
      default = 2;
      description = "Java heap for OpenSearch in GB. Upstream's installer uses half of system RAM.";
    };
  };

  config = lib.mkIf cfg.enable {
    # The compose stack runs against a system daemon; the repo's default docker
    # host is rootless and per-user.
    virtualisation.docker.enable = lib.mkDefault true;

    # OpenSearch refuses to start below this.
    boot.kernel.sysctl."vm.max_map_count" = 262144;

    # Create users with:
    #   cd /var/lib/timesketch && sudo docker compose exec timesketch-web tsctl create-user <name>
    systemd.services.timesketch = {
      description = "Timesketch (Docker Compose)";
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
        StateDirectory = "timesketch";
        StateDirectoryMode = "0700";
        TimeoutStartSec = "15min"; # first start pulls ~2 GB of images
        ExecStart = "${docker}/bin/docker compose up -d --wait --remove-orphans";
        ExecStop = "${docker}/bin/docker compose down";
      };
      preStart = ''
        umask 077
        mkdir -p data/postgresql data/opensearch logs upload etc/timesketch/sigma/rules \
          etc/timesketch/llm_summarize etc/timesketch/llm_starred_events_report etc/timesketch/nl2q
        chown 1000 data/opensearch # opensearch container user

        for s in postgres_password secret_key; do
          [ -e $s ] || openssl rand -hex 16 > $s
        done

        install -m644 ${src}/docker/release/docker-compose.yml docker-compose.yml
        install -m644 ${src}/contrib/nginx.conf etc/nginx.conf
        ${lib.concatMapStringsSep "\n" (f: "install -Dm644 ${src}/data/${f} etc/timesketch/${f}") dataFiles}

        # Same substitutions as contrib/deploy_timesketch.sh.
        sed \
          -e "s#SECRET_KEY = \"<KEY_GOES_HERE>\"#SECRET_KEY = \"$(cat secret_key)\"#" \
          -e 's#^UPLOAD_ENABLED = False#UPLOAD_ENABLED = True#' \
          -e 's#^UPLOAD_FOLDER = "/tmp"#UPLOAD_FOLDER = "/usr/share/timesketch/upload"#' \
          -e 's#^CELERY_BROKER_URL =.*#CELERY_BROKER_URL = "redis://redis:6379"#' \
          -e 's#^CELERY_RESULT_BACKEND =.*#CELERY_RESULT_BACKEND = "redis://redis:6379"#' \
          -e "s#postgresql://<USERNAME>:<PASSWORD>@localhost#postgresql://timesketch:$(cat postgres_password)@postgres:5432#" \
          ${src}/data/timesketch.conf > etc/timesketch/timesketch.conf
        if grep -qE '<KEY_GOES_HERE>|<USERNAME>|<PASSWORD>' etc/timesketch/timesketch.conf; then
          echo "timesketch.conf placeholders not substituted; upstream template changed" >&2
          exit 1
        fi

        sed \
          -e "s#^POSTGRES_PASSWORD=#POSTGRES_PASSWORD=$(cat postgres_password)#" \
          -e 's#^OPENSEARCH_MEM_USE_GB=#OPENSEARCH_MEM_USE_GB=${toString cfg.opensearchMemoryGb}#' \
          -e 's#^NGINX_HTTP_PORT=.*#NGINX_HTTP_PORT=${cfg.bindAddress}:${toString cfg.port}#' \
          -e 's#^NGINX_HTTPS_PORT=.*#NGINX_HTTPS_PORT=${cfg.bindAddress}:${toString (cfg.port + 1)}#' \
          ${src}/docker/release/config.env > .env
      '';
    };
  };
}
