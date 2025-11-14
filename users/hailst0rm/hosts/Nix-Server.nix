{...}: {
  imports = [./default.nix];

  # Override only what's different from default
  fileManager = "";
  browser = "";
  video = "";
  image = "";

  importConfig = {
    stylix.enable = false;
    hyprland = {
      enable = false;
      accentColour = "pink";
    };
  };

  code.vscode.enable = false;

  applications = {
    bitwarden.enable = false;
    discord.enable = false;
    firefox.enable = false;
    libreOffice.enable = false;
    obsidian.enable = false;
    remmina.enable = false;
    spotify.enable = false;
    claude-desktop.enable = false;
    proton.enableAll = false;
  };
}
