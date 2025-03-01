{ config, lib, pkgs, pkgs-unstable, ... }: {
  config = lib.mkIf (config.terminal == "ghostty") {
    programs.ghostty = {
      enable = true;
      package = pkgs.ghostty;
      enableZshIntegration = true;
      settings = {
        font-size = lib.mkForce 14;
        window-decoration = false;
      };
    };
  };
}
