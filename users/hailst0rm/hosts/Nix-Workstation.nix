{...}: {
  imports = [./default.nix];

  # Override only what's different from default
  importConfig.hyprland = {
    accentColour = "red";
    monitorOrientations = {
      "DP-1" = "top";
      "DP-2" = "left";
    };
  };

  code.claude-code.enable = true;

  applications = {
    youtube-music.enable = true;
    openconnect.enable = true;
  };
}
