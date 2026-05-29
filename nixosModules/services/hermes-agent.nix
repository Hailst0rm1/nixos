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
    browser = {
      enable = lib.mkEnableOption "agent-browser CLI (Vercel Labs) for the Hermes agent";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages =
      [pkgs.hermes-agent]
      ++ lib.optionals cfg.signal.enable [pkgs-unstable.signal-cli]
      ++ lib.optionals cfg.browser.enable [pkgs.agent-browser];

    environment.etc."agent-browser/config.json" = lib.mkIf cfg.browser.enable {
      text = builtins.toJSON {
        headed = config.services.vncDisplay.enable;
        profile = "/var/lib/agent-browser/profile";
      };
      mode = "0444";
    };

    systemd.tmpfiles.rules = lib.mkIf cfg.browser.enable [
      "d /var/lib/agent-browser 0750 hailst0rm users -"
      "d /var/lib/agent-browser/profile 0750 hailst0rm users -"
    ];

    systemd.services.agent-browser-install = lib.mkIf cfg.browser.enable {
      description = "One-time install of Chrome-for-Testing for agent-browser";
      after = ["network-online.target"];
      wants = ["network-online.target"];
      before = ["hermes-agent.service"];
      wantedBy = ["hermes-agent.service"];
      serviceConfig = {
        Type = "oneshot";
        User = "hailst0rm";
        RemainAfterExit = true;
        Environment = ["HOME=/home/hailst0rm"];
      };
      script = ''
        if [ ! -d "$HOME/.agent-browser/chromes" ]; then
          ${pkgs.agent-browser}/bin/agent-browser install
        fi
      '';
    };

    systemd.services.hermes-agent = {
      description = "Hermes Agent Gateway";
      after =
        ["network.target"]
        ++ lib.optionals cfg.signal.enable ["signal-cli-daemon.service"]
        ++ lib.optionals (cfg.browser.enable && config.services.vncDisplay.enable) ["vnc-display.service" "novnc.service"];
      wants = lib.optionals (cfg.browser.enable && config.services.vncDisplay.enable) ["vnc-display.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        ExecStart = "${pkgs.hermes-agent}/bin/hermes gateway";
        Restart = "on-failure";
        RestartSec = 10;
        DynamicUser = false;
        User = "hailst0rm";
        Environment =
          ["HERMES_PORT=${toString cfg.port}"]
          ++ lib.optionals cfg.browser.enable ["AGENT_BROWSER_CONFIG=/etc/agent-browser/config.json"]
          ++ lib.optionals (cfg.browser.enable && config.services.vncDisplay.enable) ["DISPLAY=:${toString config.services.vncDisplay.display}"];
        EnvironmentFile = config.sops.secrets."services/hermes-agent/env".path;
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
        EnvironmentFile = config.sops.secrets."services/hermes-agent/env".path;
      };
    };
  };
}
