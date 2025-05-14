{
  pkgs,
  pkgs-unstable,
  ...
}: {
  programs.bat.enable = true;

  services.playerctld.enable = true;

  home.packages = [
    pkgs.openvpn
    pkgs.python313
    # Advanced tooling
    pkgs-unstable.lazydocker # Docker TUI
    pkgs-unstable.lazyjournal # Journal TUI
    pkgs-unstable.glow # Markdown view
    pkgs-unstable.yazi # File-manager TUI
    pkgs-unstable.fzf # CLI Fuzzy finder
    pkgs-unstable.hexyl # Hex viewer
    pkgs-unstable.topgrade # Upgrade everything
    pkgs-unstable.gping # Graphical ping
  ];
}

