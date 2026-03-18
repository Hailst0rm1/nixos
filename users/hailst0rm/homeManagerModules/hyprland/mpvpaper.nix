{
  pkgs,
  pkgs-unstable,
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

  wallpaperDir = "${config.nixosDir}/assets/wallpapers/${accentCategory}";

  mpvpaperScript = pkgs.writeShellScriptBin "mpvpaper-wallpaper" ''
    set -euo pipefail

    WALLPAPER_DIR="${wallpaperDir}"
    PLAYLIST="/tmp/mpvpaper-playlist.m3u"

    # Build playlist from all video files in the category directory
    : > "$PLAYLIST"
    found=0
    for ext in mp4 webm mkv; do
      for f in "$WALLPAPER_DIR"/*."$ext"; do
        [ -f "$f" ] && { echo "$f" >> "$PLAYLIST"; found=1; }
      done
    done

    if [ "$found" -eq 0 ]; then
      echo "ERROR: No video wallpapers (.mp4/.webm/.mkv) found in $WALLPAPER_DIR"
      exit 1
    fi

    echo "Starting mpvpaper with $(wc -l < "$PLAYLIST") wallpapers from $WALLPAPER_DIR"
    exec ${lib.getExe pkgs-unstable.mpvpaper} \
      -f \
      -n 1800 \
      -p \
      -o "no-audio --loop-playlist --shuffle --hwdec=auto --panscan=1.0" \
      '*' \
      "$PLAYLIST"
  '';
in {
  config = lib.mkIf (config.importConfig.hyprland.enable && config.importConfig.hyprland.wallpaper == "mpvpaper") {
    services.hyprpaper.enable = lib.mkForce false;

    # Pause list: mpvpaper pauses video when these programs are running
    xdg.configFile."mpvpaper/pauselist".text = ''
      steam_app
    '';

    # Wallpaper service as a systemd user service
    systemd.user.services.mpvpaper-wallpaper = {
      Unit = {
        Description = "mpvpaper video wallpaper";
        After = ["graphical-session.target"];
      };
      Service = {
        Type = "simple";
        ExecStart = "${mpvpaperScript}/bin/mpvpaper-wallpaper";
        Restart = "on-failure";
        RestartSec = "10s";
      };
      Install = {
        WantedBy = ["graphical-session.target"];
      };
    };
  };
}
