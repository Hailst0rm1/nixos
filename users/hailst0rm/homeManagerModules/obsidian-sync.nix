{
  config,
  lib,
  pkgs,
  secretPath,
  ...
}:
with lib; let
  cfg = config.services.obsidian-sync;

  obsidian-headless = pkgs.obsidian-headless;

  e2eePath = secretPath "services/obsidian/e2ee-password";

  syncScript = pkgs.writeShellScript "obsidian-sync" ''
    set -euo pipefail

    # Verify login (ob login prompts for 2FA interactively — run `ob login` manually first)
    if ! ${obsidian-headless}/bin/ob login 2>/dev/null; then
      echo "Not logged in. Run 'ob login' manually first (2FA requires interactive input)." >&2
      exit 1
    fi

    # Setup vault if not already configured
    if ! ${obsidian-headless}/bin/ob sync-status --path "${cfg.vaultPath}" >/dev/null 2>&1; then
      E2EE_PASSWORD="$(cat "${e2eePath}")"
      ${obsidian-headless}/bin/ob sync-setup \
        --vault "${cfg.vaultName}" \
        --path "${cfg.vaultPath}" \
        --password "$E2EE_PASSWORD" \
        --device-name "${cfg.deviceName}"
    fi

    # Run continuous sync
    exec ${obsidian-headless}/bin/ob sync --path "${cfg.vaultPath}" --continuous
  '';
in {
  options.services.obsidian-sync = {
    enable = mkEnableOption "Obsidian Sync headless service";

    vaultName = mkOption {
      type = types.str;
      description = "Remote vault name or ID";
    };

    vaultPath = mkOption {
      type = types.str;
      description = "Local directory path for the vault";
    };

    deviceName = mkOption {
      type = types.str;
      default = config.hostname;
      description = "Device name shown in sync version history";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [obsidian-headless];

    systemd.user.services.obsidian-sync = {
      Unit = {
        Description = "Obsidian Sync - Headless continuous vault sync";
        After = ["network-online.target"];
        Wants = ["network-online.target"];
      };

      Service = {
        Type = "simple";
        ExecStart = "${syncScript}";
        Restart = "on-failure";
        RestartSec = "30s";
      };

      Install = {
        WantedBy = ["default.target"];
      };
    };
  };
}
