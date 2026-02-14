{...}: {
  imports = [./default.nix];

  # Minimal — only basics for bootstrapping after install
  importConfig = {
    git.enable = true;
    ssh.enable = false;
    yazi.enable = false;
    stylix.enable = false;
    sops.enable = false;
    zsh-history-sync.enable = false;
    hyprland.enable = false;
  };

  code = {
    helix.enable = false;
    vscode.enable = false;
  };

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

  services = {
    claude-mcp.enable = false;
    whisperStt.enable = false;
  };
}
