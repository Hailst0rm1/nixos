{...}: {
  imports = [./default.nix];

  # Override only what's different from default
  importConfig.hyprland = {
    quickshell = {
      enable = true;
      openweatherCityId = "2673730";
    };
    accentColour = "sky";
    monitorOrientations = {
      "DP-6" = "center";
      "DP-2" = "top";
      "DP-3" = "top";
    };
  };

  code.claude-code.enable = true;
  importConfig.zsh-history-sync.enable = true;

  applications = {
    youtube-music.enable = true;
    openconnect.enable = false;
    aws-cvpn-wrapper.enable = false;
  };
}
