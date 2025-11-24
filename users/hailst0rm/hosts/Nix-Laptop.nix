{...}: {
  imports = [./default.nix];

  # Override only what's different from default
  importConfig.hyprland = {
    accentColour = "green";
    monitorOrientations = {
      "0" = "left";
      "1" = "left";
      "2" = "top";
      "3" = "top";
    };
  };

  code.claude-code.enable = true;

  applications = {
    youtube-music.enable = true;
    openconnect.enable = true;
  };
}
