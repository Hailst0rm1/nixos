{
  pkgs,
  lib,
  config,
  ...
}: let
  # nwg-displays writes plain hyprlang monitor= lines; hyprland.nix sources this
  # file after the Nix baseline, and Hyprland reloads on every save — no rebuild.
  displaysScript = ''
    exec nwg-displays -m "${config.xdg.configHome}/hypr/monitors.conf"
  '';

  displays = pkgs.writeScriptBin "displays" displaysScript;

  ## Check if Hyprland is enabled
  hyprlandEnabled = config.importConfig.hyprland.enable;
in {
  config = {
    home.packages = lib.mkIf hyprlandEnabled [displays];
  };
}
