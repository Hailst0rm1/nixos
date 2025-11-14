{...}: {
  imports = [./default.nix];

  # Override only what's different from default
  code.claude-code.enable = true;

  applications = {
    youtube-music.enable = true;
    openconnect.enable = true;
  };
}
