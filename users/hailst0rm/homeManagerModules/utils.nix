{
  pkgs,
  pkgs-unstable,
  ...
}: {
  programs.bat.enable = true;

  services.playerctld.enable = true;

  home.packages = [
    # Advanced tooling
    pkgs-unstable.glow # Markdown view
    pkgs-unstable.helix # Code editor
    pkgs-unstable.yazi # File-manager TUI
    pkgs-unstable.fzf # CLI Fuzzy finder
    pkgs-unstable.hexyl # Hex viewer
    pkgs-unstable.topgrade # Upgrade everything
    pkgs-unstable.gping # Graphical ping
  ];
}

