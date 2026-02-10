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

    user = mkOption {
      type = types.str;
      default = config.username or "hailst0rm";
      description = "User to run The Vibe Companion as";
    };

    group = mkOption {
      type = types.str;
      default = "users";
      description = "Group to run The Vibe Companion as";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to open the firewall for The Vibe Companion";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.companion = {
      description = "The Vibe Companion - Web UI for Claude Code";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];

      environment = {
        PORT = toString cfg.port;
        NODE_ENV = "production";
      };

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${(pkgs.callPackage ../../pkgs/companion/package.nix {})}/bin/the-vibe-companion";
        Restart = "on-failure";
        RestartSec = "5s";

        # Security hardening
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        ReadWritePaths = ["/home/${cfg.user}/.companion"];

        # Resource limits
        LimitNOFILE = 65536;
      };
    };

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [cfg.port];

    # Ensure the companion package is available
    environment.systemPackages = [(pkgs.callPackage ../../pkgs/companion/package.nix {})];
  };
}
