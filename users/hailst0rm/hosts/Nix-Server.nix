{...}: {
  imports = [./default.nix];

  # Override only what's different from default
  fileManager = "";
  browser = "";
  video = "";
  image = "";

  programs.zsh.initContent = ''
    eval "$(direnv hook zsh)"
  '';

  importConfig = {
    stylix.enable = false;
    hyprland = {
      enable = false;
      accentColour = "pink";
    };
  };

  code.vscode.enable = false;
  code.claude-code.enable = true;

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
