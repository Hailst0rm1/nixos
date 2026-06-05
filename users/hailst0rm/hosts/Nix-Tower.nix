{...}: {
  imports = [./default.nix];

  # Override only what's different from default
  importConfig.hyprland = {
    accentColour = "sky";
    monitorOrientations = {
      "DP-1" = "center";
      "DP-2" = "top";
      "DP-3" = "top";
    };
  };

  code.claude-code.enable = true;
  code.codex.enable = true;
  code.sandcastle = {
    maxIssues = 1;
    concurrency = 1;
  };
  importConfig.zsh-history-sync.enable = true;

  applications = {
    youtube-music.enable = true;
    openconnect.enable = false;
    aws-cvpn-wrapper.enable = false;
  };
}
