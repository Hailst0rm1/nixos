{
  pkgs,
  config,
  lib,
  ...
}: let
  startSwww = pkgs.writeShellScriptBin "start" ''
    # Wallpaper
    ${pkgs.swww}/bin/swww-daemon &
    set -e
    while true; do
      BG=`find ${../wallpapers} -name "*.gif" | shuf -n1`
      if pgrep swww-daemon >/dev/null; then
        swww img "$BG" \
          --resize crop \
          --transition-fps 60 \
          --transition-duration 2 \
          --transition-type random \
          --transition-pos top-right \
          --transition-bezier .3,0,0,.99 \
          --transition-angle 135 || true
        sleep 1800
      else
        (swww-daemon 1>/dev/null 2>/dev/null &) || true
        sleep 1
      fi
    done
  '';
in {
  config = lib.mkIf (config.importConfig.hyprland.wallpaper == "swww") {
    services.hyprpaper.enable = lib.mkForce false;

    wayland.windowManager.hyprland.settings.exec-once = [
      "${pkgs.bash}/bin/bash ${startSwww}/bin/start"
    ];
  };
}
