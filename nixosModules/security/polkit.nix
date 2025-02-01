{ config, lib, ...}: {
  options.security.completePolkit.enable = lib.mkEnableOption "Enable polkit";

  config = lib.mkIf config.security.completePolkit.enable {

    security.polkit = {
      enable = true;
    };
    programs.gnupg.agent.enable = true;
  };
}

