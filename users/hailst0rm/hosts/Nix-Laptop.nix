{...}: {
  imports = [./default.nix];

  # Override only what's different from default
  importConfig.hyprland = {
    accentColour = "green";
    wallpaper = "swww";
    quickshell.ilyamiro.lockIcon = ../../../assets/images/mountain.jpg;
    monitorOrientations = {
      "eDP-1" = "left"; # Middle horizontal monitor (1920x1080)
      "DP-3" = "center"; # Middle horizontal monitor (1920x1080)
      "DP-4" = "top"; # Right vertical monitor (2560x1440, transform 3)
      "DP-5" = "top"; # Left vertical monitor (2560x1440, transform 1)
    };
  };

  code.claude-code.enable = true;
  code.claude-code.tokenOptimizer.enable = false;
  code.codex.enable = true;
  code.sandcastle = {
    maxIssues = 1;
    concurrency = 1;
  };
  services.claudecodeui.enable = false;

  # PRIME-offload laptop: dGPU isn't woken by whisper's --device cuda path,
  # so transcription effectively runs on the iGPU/CPU. Drop to small (multilingual)
  # for usable latency until a persistent daemon / proper offload wrapper is wired.
  services.whisperStt.model = "small";

  applications = {
    youtube-music.enable = true;
    openconnect.enable = true;
    aws-cvpn-wrapper.enable = false;
  };
}
