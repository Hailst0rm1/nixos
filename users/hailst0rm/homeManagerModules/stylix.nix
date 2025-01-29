{ lib, config, ...}:
let
  cfg = config.importConfig.stylix;
in {
  options.importConfig.stylix = {
    enable = lib.mkEnableOption "Enable user stylix config.";
  };

  config = lib.mkIf cfg.enable {
    stylix = {
      enable = true;
      autoEnable = true;
      targets = {
        ghostty.enable = true;
        helix.enable = false;
      };
    };
  };
}
