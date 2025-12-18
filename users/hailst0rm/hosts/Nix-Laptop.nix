{...}: {
  imports = [./default.nix];

  # Override only what's different from default
  importConfig.hyprland = {
    accentColour = "green";
    monitorOrientations = {
      "eDP-1" = "left"; # Middle horizontal monitor (1920x1080)
      "DP-3" = "left"; # Middle horizontal monitor (1920x1080)
      "DP-4" = "top"; # Right vertical monitor (2560x1440, transform 3)
      "DP-5" = "top"; # Left vertical monitor (2560x1440, transform 1)
    };
  };

  code.claude-code.enable = true;

  applications = {
    youtube-music.enable = true;
    openconnect.enable = true;
    aws-cvpn-wrapper.enable = true;
  };
}
