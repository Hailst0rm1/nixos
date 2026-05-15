{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}: let
  cfg = config.services.hermes-agent;
in {
  options.services.hermes-agent = {
    enable = lib.mkEnableOption "Hermes Agent gateway by Nous Research";
    port = lib.mkOption {
      type = lib.types.port;
      default = 8333;
      description = "Port Hermes Agent gateway listens on.";
    };
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/hermes-agent";
      description = "Persistent data directory.";
    };
    signal = {
      enable = lib.mkEnableOption "signal-cli HTTP daemon for Hermes Signal integration";
      port = lib.mkOption {
        type = lib.types.port;
        default = 8080;
        description = "Port signal-cli HTTP daemon listens on.";
      };
    };
    dashboard = {
      enable = lib.mkEnableOption "Hermes Agent web dashboard";
      port = lib.mkOption {
        type = lib.types.port;
        default = 9119;
        description = "Port the dashboard listens on.";
      };
      host = lib.mkOption {
        type = lib.types.str;
        default = "0.0.0.0";
        description = "Host address to bind.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages =
      [pkgs.hermes-agent]
      ++ lib.optionals cfg.signal.enable [pkgs-unstable.signal-cli];

    systemd.services.hermes-agent = {
      description = "Hermes Agent Gateway";
      after =
        ["network.target"]
        ++ lib.optionals cfg.signal.enable ["signal-cli-daemon.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        ExecStart = "${pkgs.hermes-agent}/bin/hermes gateway";
        Restart = "on-failure";
        RestartSec = 10;
        DynamicUser = false;
        User = "hailst0rm";
        Environment = [
          "HOME=${cfg.dataDir}"
          "HERMES_PORT=${toString cfg.port}"
        ];
        EnvironmentFile = config.sops.secrets."services/hermes-agent/env".path;
        StateDirectory = "hermes-agent";
        WorkingDirectory = cfg.dataDir;
      };
    };

    systemd.services.signal-cli-daemon = lib.mkIf cfg.signal.enable {
      description = "signal-cli HTTP daemon";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];
      script = ''
        ACCOUNT=$(cat ${config.sops.secrets."services/signal-cli/account".path})
        exec ${pkgs-unstable.signal-cli}/bin/signal-cli --account "$ACCOUNT" daemon --http 127.0.0.1:${toString cfg.signal.port}
      '';
      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = 10;
        DynamicUser = false;
        User = "hailst0rm";
        Environment = ["HOME=${cfg.dataDir}"];
        WorkingDirectory = cfg.dataDir;
      };
    };

    systemd.services.hermes-dashboard = lib.mkIf cfg.dashboard.enable {
      description = "Hermes Agent Web Dashboard";
      after = ["network.target" "hermes-agent.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        ExecStart = "${pkgs.hermes-agent}/bin/hermes dashboard --host ${cfg.dashboard.host} --port ${toString cfg.dashboard.port} --insecure --no-open";
        Restart = "on-failure";
        RestartSec = 10;
        DynamicUser = false;
        User = "hailst0rm";
        Environment = [
          "HOME=${cfg.dataDir}"
        ];
        EnvironmentFile = config.sops.secrets."services/hermes-agent/env".path;
        WorkingDirectory = cfg.dataDir;
      };
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 hailst0rm users -"
      "d ${cfg.dataDir}/.hermes 0750 hailst0rm users -"
    ];
  };
}
