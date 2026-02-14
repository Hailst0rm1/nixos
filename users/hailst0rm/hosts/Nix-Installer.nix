{...}: {
  imports = [./default.nix];

  # Installer — browser for docs, git for cloning, terminal basics
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
    firefox.enable = true; # Keep for documentation access
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
