{...}: {
  imports = [./default.nix];

  # Override only what's different from default
  importConfig.hyprland = {
    accentColour = "green";
    monitorOrientations = {
      "0" = "center"; # Middle horizontal monitor (1920x1080)
      "1" = "top"; # Right vertical monitor (2560x1440, transform 3)
      "2" = "top"; # Left vertical monitor (2560x1440, transform 1)
    };
  };

  code.claude-code.enable = true;
  importConfig.zsh-history-sync.enable = false;

  applications = {
    youtube-music.enable = true;
    openconnect.enable = true;
    aws-cvpn-wrapper.enable = true;
  };
}
