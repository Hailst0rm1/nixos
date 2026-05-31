{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.code.claude-code;

  claudePkg = config.programs.claude-code.finalPackage;

  # Single source of truth: the same enabledPlugins set declared in
  # claude-code.nix. Keep only entries explicitly set to true.
  enabledPlugins =
    lib.attrNames
    (lib.filterAttrs (_: v: v) config.programs.claude-code.settings.enabledPlugins);

  # Refresh marketplace clones, then pull each enabled plugin to the latest
  # version. Claude Code does NOT auto-pull: marketplace clones under
  # ~/.claude/plugins/marketplaces/ and the installed code under
  # ~/.claude/plugins/cache/<mp>/<plugin>/<version>/ stay frozen until these
  # commands run. `claude plugin update` requires a restart to apply, so the
  # refreshed version lands in the NEXT Claude Code session.
  updateScript = pkgs.writeShellScriptBin "claude-plugins-update" ''
    set -u

    # The Home Manager wrapper appends `--mcp-config` to every `claude` call,
    # which the `plugin` subcommands reject. Prefer the unwrapped binary
    # (makeWrapper leaves it beside the wrapper as `.claude-wrapped`); fall
    # back to the wrapper if this build isn't wrapped.
    CLAUDE="${claudePkg}/bin/.claude-wrapped"
    [ -x "$CLAUDE" ] || CLAUDE="${claudePkg}/bin/claude"

    echo "==> Refreshing marketplace clones"
    "$CLAUDE" plugin marketplace update || true

    echo "==> Updating enabled plugins"
    for plugin in ${lib.escapeShellArgs enabledPlugins}; do
      echo "--> $plugin"
      "$CLAUDE" plugin update "$plugin" || true
    done
  '';
in {
  options.code.claude-code.pluginAutoUpdate.enable =
    lib.mkEnableOption "Periodically refresh Claude Code marketplaces and enabled plugins via a systemd user timer";

  config = lib.mkIf (cfg.enable && cfg.pluginAutoUpdate.enable) {
    home.packages = [updateScript];

    systemd.user.services.claude-plugins-update = {
      Unit = {
        Description = "Refresh Claude Code marketplaces and enabled plugins";
        After = ["network-online.target"];
      };

      Service = {
        Type = "oneshot";
        ExecStart = "${updateScript}/bin/claude-plugins-update";
        RemainAfterExit = false;
      };
    };

    systemd.user.timers.claude-plugins-update = {
      Unit = {
        Description = "Periodically refresh Claude Code plugins";
      };

      Timer = {
        # Daily. Persistent + OnCalendar means a run missed while the machine
        # was off fires shortly after the next boot (Persistent has no effect
        # with OnBootSec/OnUnitActiveSec — it only catches up against OnCalendar).
        OnCalendar = "daily";
        Persistent = true;
      };

      Install = {
        WantedBy = ["timers.target"];
      };
    };
  };
}
