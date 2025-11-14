{...}: {
  imports = [./default.nix];

  # Override only what's different from default
  importConfig.hyprland = {
    accentColour = "red";
    monitorOrientations = {
      "0" = "top";
      "1" = "left";
    };
  };

  applications = {
    youtube-music.enable = true;
    openconnect.enable = true;
  };
}
