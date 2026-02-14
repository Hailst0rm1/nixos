{
  config,
  lib,
  pkgs,
  ...
}
:
with lib; let
  cfg = config.services.companion;
in {
  options.services.companion = {
    enable = mkEnableOption "The Vibe Companion - Web UI for Claude Code agents";

    port = mkOption {
      type = types.port;
      default = 3456;
      description = "Port to run The Vibe Companion on";
    };
  };

  config = mkIf cfg.enable {
    # Add companion to user packages
    home.packages = [pkgs.companion];

    # Enable lingering so the service runs even when not logged in
    systemd.user.startServices = "sd-switch";

    # Create systemd user service
    systemd.user.services.companion = {
      Unit = {
        Description = "The Vibe Companion - Web UI for Claude Code";
        After = ["graphical-session.target"];
      };

      Service = {
        Type = "simple";
        ExecStart = "${pkgs.companion}/bin/the-vibe-companion";
        Restart = "on-failure";
        RestartSec = "5s";

        Environment = [
          "PORT=${toString cfg.port}"
          "NODE_ENV=production"
          "PATH=${config.home.profileDirectory}/bin:/run/wrappers/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin:/usr/local/bin:/usr/bin:/bin"
        ];

        # Better resource limits for user service
        LimitNOFILE = "65536";
      };

      Install = {
        WantedBy = ["default.target"];
      };
    };
  };
}
