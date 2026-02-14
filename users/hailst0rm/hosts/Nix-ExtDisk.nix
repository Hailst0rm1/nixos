{lib, ...}: {
  imports = [./default.nix];

  # Override only what's different from default
  home.stateVersion = lib.mkForce "24.11";

  importConfig = {
    ssh.enable = false;
    zsh-history-sync.enable = false;
    hyprland.enable = true;
  };

  applications = {
    claude-desktop.enable = false;
    proton.enableAll = false;
  };

  services.claude-mcp.enable = false;
}
