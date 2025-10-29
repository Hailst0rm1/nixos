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
      settings = {
        user = {
          name = "hailst0rm";
          email = "kevin.ponton@pm.me";
        };
      };
    };
  };
}
