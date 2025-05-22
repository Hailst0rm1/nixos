{
  config,
  lib,
  ...
}: let
  cfg = config.importConfig.git;
in {
  options.importConfig.git.enable = lib.mkEnableOption "Enable Git configuration.";

  config = lib.mkIf cfg.enable {
    programs.git = {
      enable = true;
      userName = "hailst0rm";
      userEmail = "kevin.ponton@pm.me";
    };
  };
}
