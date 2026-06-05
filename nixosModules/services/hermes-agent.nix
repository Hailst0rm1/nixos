{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}: let
  cfg = config.services.hermes-agent;

  # When a remote backend URL is configured, ship a wrapped desktop that
  # auto-connects to it via HERMES_DESKTOP_REMOTE_URL / _REMOTE_TOKEN. This
  # skips first-launch onboarding and stops the app bootstrapping its own
  # local Hermes install. The token is read from sops at launch (never baked
  # into the store) and must match the server's HERMES_DASHBOARD_SESSION_TOKEN.
  hermesDesktopPkg =
    if cfg.desktop.remoteUrl != ""
    then
      pkgs.symlinkJoin {
        name = "hermes-desktop-remote";
        paths = [pkgs.hermes-desktop];
        nativeBuildInputs = [pkgs.makeWrapper];
        postBuild = ''
          wrapProgram $out/bin/hermes-desktop \
            --set HERMES_DESKTOP_REMOTE_URL "${cfg.desktop.remoteUrl}" \
            --run 'export HERMES_DESKTOP_REMOTE_TOKEN="$(cat ${config.sops.secrets."services/hermes-agent/desktop-token".path})"'
        '';
      }
    else pkgs.hermes-desktop;
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
    discord = {
      homeChannel = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Discord channel ID used as the default Hermes home channel.";
      };
      allowedChannels = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Discord channel IDs where Hermes is allowed to respond. Thread parent channels are matched by Hermes.";
      };
      ignoredChannels = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Discord channel IDs where Hermes never responds, even when mentioned.";
      };
    };
    desktop = {
      enable = lib.mkEnableOption "Hermes desktop (Electron) app — a native client that can drive a local or remote Hermes backend";
      remoteUrl = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "http://100.84.181.70:9119";
        description = ''
          Remote Hermes dashboard backend URL. When set, the desktop is wrapped
          to auto-connect there (HERMES_DESKTOP_REMOTE_URL) and read its session
          token from the services/hermes-agent/desktop-token sops secret
          (HERMES_DESKTOP_REMOTE_TOKEN) — skipping onboarding and the local
          backend bootstrap. Leave empty to manage the local/remote backend
          from the app's Settings → Gateway instead.
        '';
      };
    };
  };

  config = lib.mkMerge [
    # The desktop app is a standalone client; it must install without
    # standing up a gateway/dashboard, so gate it on desktop.enable alone.
    (lib.mkIf cfg.desktop.enable {
      environment.systemPackages = [hermesDesktopPkg];
    })

    (lib.mkIf cfg.enable {
      environment.systemPackages =
        [pkgs.hermes-agent pkgs.tmux]
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
            ++ lib.optional (cfg.discord.homeChannel != "") "DISCORD_HOME_CHANNEL=${cfg.discord.homeChannel}"
            ++ lib.optional (cfg.discord.allowedChannels != []) "DISCORD_ALLOWED_CHANNELS=${lib.concatStringsSep "," cfg.discord.allowedChannels}"
            ++ lib.optional (cfg.discord.ignoredChannels != []) "DISCORD_IGNORED_CHANNELS=${lib.concatStringsSep "," cfg.discord.ignoredChannels}"
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
          # --insecure runs the dashboard in legacy session-token mode
          # (auth_required=false): the WS authenticates via ?token=<token>,
          # which is what the desktop client uses over env vars. Set a stable
          # token by adding HERMES_DASHBOARD_SESSION_TOKEN=<token> to the
          # services/hermes-agent/env sops blob (otherwise a random one is
          # generated each boot). This is safe ONLY because port 9119 is
          # reachable on the Tailscale tailnet (and loopback) — never expose it
          # publicly; the tailnet is the trust boundary.
          #
          # The embedded chat WebSocket channels (/api/ws, /api/events, /api/pty,
          # /api/pub) the desktop client needs are now served unconditionally by
          # the dashboard web server — there is no per-channel flag to toggle.
          # (The old global `--tui` flag selected the chat REPL frontend and was
          # never a dashboard option; passing it to the `dashboard` subcommand
          # now fails argparse with "unrecognized arguments: --tui".)
          # --skip-build reuses the prebuilt web assets for faster startup.
          ExecStart = "${pkgs.hermes-agent}/bin/hermes dashboard --host ${cfg.dashboard.host} --port ${toString cfg.dashboard.port} --insecure --no-open --skip-build";
          Restart = "on-failure";
          RestartSec = 10;
          DynamicUser = false;
          User = "hailst0rm";
          EnvironmentFile = config.sops.secrets."services/hermes-agent/env".path;
        };
      };
    })
  ];
}
