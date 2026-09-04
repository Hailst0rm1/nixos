{
  config,
  lib,
  pkgs,
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
      };

      Install.WantedBy = ["default.target"];
    };
  };
}
