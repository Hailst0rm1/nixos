{
  pkgs,
  lib,
  config,
  ...
}: let
  helpScript = ''
    echo "[i] Run one of the following commands: get-alias get-commands get-keybinds"
  '';

  help = pkgs.writeScriptBin "help" helpScript;
  hyprlandEnabled = config.importConfig.hyprland.enable;
in {
  config = {
    home.packages = lib.mkIf hyprlandEnabled [help];
  };
}
