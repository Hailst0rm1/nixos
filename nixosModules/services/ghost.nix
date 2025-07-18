{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}: let
  cfg = config.services.ghost;
in
  with lib; {
    options.services.ghost = {
      enable = mkEnableOption "Enable ghost blog service.";

      #   loginServer = mkOption {
      #     type = types.str;
      #     default = "";
      #     description = "The login server to use for authentication with Tailscale";
      #   };

      #   advertiseExitNode = mkOption {
      #     type = types.bool;
      #     default = false;
      #     description = "Whether to advertise this node as an exit node";
      #   };

      #   exitNode = mkOption {
      #     type = types.str;
      #     default = "";
      #     description = "The exit node to use for this node";
      #   };

      #   exitNodeAllowLanAccess = mkOption {
      #     type = types.bool;
      #     default = false;
      #     description = "Whether to allow LAN access to this node";
      #   };
    };

    config = mkIf cfg.enable {
      environment.systemPackages = [pkgs-unstable.ghost-cli];
    };
  }
