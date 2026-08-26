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

    # claude-code.nix now wraps with `--mcp-config=<file>` ahead of "$@", so
    # `claude plugin …` works through the wrapper again. We still prefer the
    # unwrapped binary (makeWrapper leaves it beside the wrapper as
    # `.claude-wrapped`) — this script wants no MCP servers spawned at all —
    # and fall back to the wrapper if this build isn't wrapped.
    CLAUDE="${claudePkg}/bin/.claude-wrapped"
    [ -x "$CLAUDE" ] || CLAUDE="${claudePkg}/bin/claude"

    rc=0

    # The marketplace refresh is the step that fails when the network isn't
    # truly ready (e.g. the timer fires seconds after boot, before GitHub SSH
    # is reachable — it dies with ERR_STREAM_PREMATURE_CLOSE and falls back to
    # stale cached versions). A non-zero exit here propagates out so the unit's
    # Restart=on-failure retries every 10 min until connectivity returns; a
    # clean run exits 0 and the retry loop stops until the next daily trigger.
    echo "==> Refreshing marketplace clones"
    if ! "$CLAUDE" plugin marketplace update; then
      echo "!! marketplace refresh failed — will retry" >&2
      rc=1
    fi

    echo "==> Updating enabled plugins"
    for plugin in ${lib.escapeShellArgs enabledPlugins}; do
      echo "--> $plugin"
      # Per-plugin failures are logged but do NOT gate the retry: once the
      # marketplace refresh succeeds, one flaky plugin shouldn't pin the unit
      # in a 10-minute retry loop forever.
      out="$("$CLAUDE" plugin update "$plugin" 2>&1)" || echo "!! update failed: $plugin" >&2
      printf '%s\n' "$out"
      # The step above cheerfully prints "Successfully updated N marketplace(s)"
      # and exits 0 even when every clone failed, so its exit code cannot gate
      # the retry. This warning on the per-plugin output is the only honest
      # signal that the clone is stale — without it a boot-race failure exits 0,
      # Restart=on-failure never fires, and plugins stay frozen until the next
      # reboot races the network again (impeccable sat on 3.6.0 for six weeks).
      case $out in
        *"marketplace not refreshed"*)
          echo "!! stale marketplace for $plugin — will retry" >&2
          rc=1
          ;;
      esac
    done

    exit $rc
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
        # Type=exec (not oneshot) so Restart= is honoured — systemd forbids
        # Restart with Type=oneshot. The job still runs to completion and
        # exits; on a non-zero exit (marketplace refresh failed) systemd
        # retries every 10 min until it exits 0, then stops until the next
        # daily trigger. The 10-min spacing stays well under systemd's default
        # start-rate limit, so the retries never get throttled.
        Type = "exec";
        ExecStart = "${updateScript}/bin/claude-plugins-update";
        # A systemd user unit inherits only systemd's own bin dir in PATH.
        # Claude Code shells out to `git ... clone` (over SSH) to refresh each
        # marketplace clone; without git+ssh on PATH the spawn fails as
        # ERR_STREAM_PREMATURE_CLOSE, `plugin marketplace update` still exits 0,
        # and every plugin silently reports "already at the latest version"
        # against a frozen clone. Non-git marketplaces (claude-plugins-official)
        # refresh over HTTPS and hid the breakage.
        Environment = ["PATH=${lib.makeBinPath [pkgs.git pkgs.openssh]}"];
        Restart = "on-failure";
        RestartSec = 600;
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
