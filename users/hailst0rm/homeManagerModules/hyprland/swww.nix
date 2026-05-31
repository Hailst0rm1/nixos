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

    # Wait for swww-daemon to be ready (query the socket — authoritative, unlike pgrep)
    retries=0
    until swww query >/dev/null 2>&1; do
      if [ "$retries" -ge 30 ]; then
        echo "ERROR: swww-daemon not ready after 30s, giving up"
        exit 1
      fi
      echo "Waiting for swww-daemon... ($retries/30)"
      sleep 1
      retries=$((retries + 1)) # assignment always returns 0 — safe under set -e
    done
    echo "swww-daemon is ready"

    # Collect static wallpapers once, sorted for a stable cycle order
    mapfile -t WALLPAPERS < <(find "$WALLPAPER_DIR" \( -name "*.jpg" -o -name "*.jpeg" -o -name "*.png" \) 2>/dev/null | sort)
    if [ "''${#WALLPAPERS[@]}" -eq 0 ]; then
      echo "WARNING: No wallpapers found in $WALLPAPER_DIR"
      exit 0 # genuine misconfig — don't crash-loop
    fi

    # Cycle through the wallpapers in order (guaranteed alternation)
    idx=0
    while true; do
      BG="''${WALLPAPERS[$idx]}"
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

      idx=$(((idx + 1) % ''${#WALLPAPERS[@]}))
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
        StartLimitIntervalSec = 60;
        StartLimitBurst = 5; # after 5 failures in 60s, stop instead of flapping forever
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
