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

  wallpaperDir = "${config.nixosDir}/assets/wallpapers/${accentCategory}";

  wallpaperScript = pkgs.writeShellScriptBin "swww-wallpaper" ''
    set -euo pipefail

    WALLPAPER_DIR="${wallpaperDir}"
    INTERVAL=1800

    # Wait for swww-daemon to be ready
    retries=0
    while ! pgrep -x swww-daemon >/dev/null 2>&1; do
      if [ $retries -ge 30 ]; then
        echo "ERROR: swww-daemon not running after 30s, giving up"
        exit 1
      fi
      echo "Waiting for swww-daemon... ($retries/30)"
      sleep 1
      ((retries++))
    done
    echo "swww-daemon is running"

    # Set initial wallpaper immediately, then loop
    while true; do
      BG=$(find "$WALLPAPER_DIR" -name "*.gif" 2>/dev/null | shuf -n1)
      if [ -z "$BG" ]; then
        echo "WARNING: No wallpapers found in $WALLPAPER_DIR"
        sleep 60
        continue
      fi

      echo "Setting wallpaper: $BG"
      if swww img "$BG" \
        --transition-fps 60 \
        --transition-duration 2 \
        --transition-type random \
        --transition-pos top-right \
        --transition-bezier .3,0,0,.99 \
        --transition-angle 135; then
        echo "Wallpaper applied successfully"
      else
        echo "WARNING: Failed to apply wallpaper: $BG"
      fi

      sleep $INTERVAL
    done
  '';
in {
  config = lib.mkIf (config.importConfig.hyprland.enable && config.importConfig.hyprland.wallpaper == "swww") {
    services.hyprpaper.enable = lib.mkForce false;

    # Start the swww daemon via exec-once (needs to run in the Wayland session)
    wayland.windowManager.hyprland.settings.exec-once = [
      "${pkgs.swww}/bin/swww-daemon"
    ];

    # Wallpaper rotation as a systemd user service
    systemd.user.services.swww-wallpaper = {
      Unit = {
        Description = "swww wallpaper rotation";
        After = ["graphical-session.target"];
      };
      Service = {
        Type = "simple";
        ExecStart = "${wallpaperScript}/bin/swww-wallpaper";
        Restart = "on-failure";
        RestartSec = "10s";
        Environment = [
          "PATH=${lib.makeBinPath [pkgs.swww pkgs.findutils pkgs.coreutils pkgs.procps pkgs.gnugrep]}:$PATH"
        ];
      };
      Install = {
        WantedBy = ["graphical-session.target"];
      };
    };
  };
}
