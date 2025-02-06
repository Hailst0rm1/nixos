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
      opacity = {
        applications = 0.9;
        desktop = 0.9;
        popups = 0.9;
        terminal = 0.9;
      };

      targets = {
        ghostty.enable = true;
        helix.enable = false;
        #nixcord.enable = true; On next release or when backported
      };
    };
  };
}
