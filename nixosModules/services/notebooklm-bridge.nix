{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.notebooklm-bridge;
  notebooklm-py = pkgs.callPackage ../../pkgs/notebooklm-py/package.nix {};
  bridgeScript = ../../pkgs/notebooklm-bridge/bridge.py;
  python = pkgs.python3.withPackages (_: []);
in {
  options.services.notebooklm-bridge = {
    enable = lib.mkEnableOption "NotebookLM HTTP bridge for n8n integration";
    port = lib.mkOption {
      type = lib.types.port;
      default = 9090;
      description = "Port the bridge listens on.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.notebooklm-bridge = {
      description = "NotebookLM HTTP Bridge";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        ExecStart = "${python}/bin/python ${bridgeScript} ${toString cfg.port}";
        Restart = "on-failure";
        RestartSec = 5;
        DynamicUser = false;
        User = "hailst0rm";
        Environment = "HOME=/home/hailst0rm NOTEBOOKLM_BIN=${notebooklm-py}/bin/notebooklm";
      };
    };
  };
}
