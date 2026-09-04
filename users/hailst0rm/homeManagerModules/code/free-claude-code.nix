{
  config,
  lib,
  pkgs,
  secretPath,
  ...
}: let
  cfg = config.code.claude-code.freeClaudeCode;
  fcc = pkgs.symlinkJoin {
    name = "free-claude-code-wrapped";
    paths = [pkgs.free-claude-code];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      for command in $out/bin/fcc-*; do
        wrapProgram "$command" --set PORT ${toString cfg.port}
      done
    '';
  };
in {
  options.code.claude-code.freeClaudeCode = {
    enable = lib.mkEnableOption "Free Claude Code proxy" // {default = true;};
    port = lib.mkOption {
      type = lib.types.port;
      default = 38427;
      description = "Local port for the Free Claude Code proxy.";
    };
    model = lib.mkOption {
      type = lib.types.str;
      default = "nvidia_nim/nvidia/nemotron-3-super-120b-a12b";
      description = ''
        Primary model every Claude request is routed to, as `provider/model/name`.
        Passed as MODEL in the service environment, which outranks whatever the
        `/admin` UI wrote into `~/.fcc/.env` (config/loader.py applies process
        env over managed dotenv values). Edit here, not in the UI.
      '';
    };
    fallbackModels = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "open_router/z-ai/glm-5.2:free"
        "open_router/minimax/minimax-m2.7:free"
        "open_router/openrouter/free"
      ];
      description = ''
        Ordered fallbacks tried when the primary fails; joined into
        MODEL_FALLBACKS. Any provider failure on an uncommitted stream advances
        to the next candidate, so a delisted model costs one wasted round-trip
        rather than an outage.

        Keep a provider-side router last — `open_router/openrouter/free` picks a
        live free model itself, so the floor of the chain never goes stale when
        upstream rotates model names. List what is currently routable with:
        `curl -s localhost:${toString cfg.port}/v1/models | jq -r '.data[].id' | sed -n 's|^anthropic/||p'`
      '';
    };
  };

  config = lib.mkIf (config.code.claude-code.enable && cfg.enable) {
    home.packages = [fcc];

    systemd.user.services.free-claude-code = {
      Unit = {
        Description = "Free Claude Code proxy";
        After = ["network-online.target"];
        Wants = ["network-online.target"];
      };

      Service = {
        ExecStart = "${fcc}/bin/fcc-server";
        Restart = "on-failure";
        RestartSec = 5;

        Environment =
          ["MODEL=${cfg.model}"]
          ++ lib.optional (cfg.fallbackModels != [])
          "MODEL_FALLBACKS=${lib.concatStringsSep "," cfg.fallbackModels}";

        # Provider API keys, as KEY=value lines. EnvironmentFile (not
        # Environment=) so they stay out of `systemctl show`; leading `-` so the
        # unit still starts on a host without sops.
        EnvironmentFile = "-${secretPath "services/free-claude-code/env"}";
      };

      Install.WantedBy = ["default.target"];
    };
  };
}
