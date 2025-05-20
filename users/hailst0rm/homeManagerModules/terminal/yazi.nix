{
  config,
  lib,
  pkgs-unstable,
  ...
}: let
  cfg = config.importConfig.yazi;
in {
  options.importConfig.yazi.enable = lib.mkEnableOption "Enable Yazi file manager.";

  config = lib.mkIf cfg.enable {
    programs.yazi = {
      enable = true;
      package = pkgs-unstable.yazi;
      enableZshIntegration = true;

      settings = {
        manager = {
          ratio = [2 2 4];
          show_hidden = true;
        };
      };

      theme = {
        status = {
          separator_open = "█";
          separator_close = "█";
        };
      };
    };
  };
}
