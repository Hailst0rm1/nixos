{
  pkgs,
  config,
  lib,
  ...
}: let
  accent = config.importConfig.hyprland.accentColour;

  # Mapping accent color name to category
  accentMap = {
    rosewater = "pink";
    flamingo = "pink";
    pink = "pink";
    mauve = "pink";
    lavender = "pink";

    red = "red";
    maroon = "red";
    peach = "red";

    yellow = "yellow";

    green = "green";
    teal = "green";

    sky = "blue";
    sapphire = "blue";
    blue = "blue";
  };

  # Look up the category (fail with helpful error if undefined)
  accentCategory = lib.attrByPath [accent] (throw "Unknown accentColour: ${accent}") accentMap;

  startSwww = pkgs.writeShellScriptBin "start" ''
    # Wallpaper
    swww-daemon &
    set -e
    while true; do
      BG=`find ${config.nixosDir}/assets/wallpapers/${accentCategory} -name "*.gif" | shuf -n1`
      if pgrep swww-daemon >/dev/null; then
        swww img "$BG" \
          --transition-fps 60 \
          --transition-duration 2 \
          --transition-type random \
          --transition-pos top-right \
          --transition-bezier .3,0,0,.99 \
          --transition-angle 135 || true
          # --resize fit bugged on 0.10.2
        sleep 1800
      else
        (swww-daemon 1>/dev/null 2>/dev/null &) || true
        sleep 1
      fi
    done
  '';
in {
  config = lib.mkIf (config.importConfig.hyprland.enable && config.importConfig.hyprland.wallpaper == "swww") {
    services.hyprpaper.enable = lib.mkForce false;

    wayland.windowManager.hyprland.settings.exec-once = [
      "${pkgs.bash}/bin/bash ${startSwww}/bin/start"
    ];
  };
}
