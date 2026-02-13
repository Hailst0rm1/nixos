{...}: {
  imports = [./default.nix];

  # Override only what's different from default
  importConfig = {
    ssh.enable = false;
    zsh-history-sync.enable = false;
    hyprland.enable = false;
  };

  code.vscode.enable = false;

  applications = {
    bitwarden.enable = false;
    discord.enable = false;
    libreOffice.enable = false;
    remmina.enable = false;
    spotify.enable = false;
    claude-desktop.enable = false;
    openconnect.enable = true;
    proton.enableAll = false;
  };

  services.claude-mcp.enable = false;
}
