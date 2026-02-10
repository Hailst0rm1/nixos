{
  config,
  lib,
  pkgs,
  ...
}:
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
    home.packages = [(pkgs.callPackage ../../../pkgs/companion/package.nix {})];

    # Create systemd user service
    systemd.user.services.companion = {
      Unit = {
        Description = "The Vibe Companion - Web UI for Claude Code";
        After = ["graphical-session.target"];
      };

      Service = {
        Type = "simple";
        ExecStart = "${pkgs.callPackage ../../../pkgs/companion/package.nix {}}/bin/the-vibe-companion";
        Restart = "on-failure";
        RestartSec = "5s";

        Environment = [
          "PORT=${toString cfg.port}"
          "NODE_ENV=production"
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
