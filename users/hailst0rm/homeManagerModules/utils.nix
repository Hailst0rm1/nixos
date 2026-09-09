{
  pkgs,
  pkgs-unstable,
  ...
}: {
  programs.bat.enable = true;

  # Writes ~/.config/user-dirs.dirs — without it XDG_VIDEOS_DIR etc. are unset
  # and apps like Snapshot refuse to save recordings.
  xdg.userDirs.enable = true;
  # Keeps the pre-26.05 behaviour of exporting XDG_*_DIR into the session.
  # quickshell-config/screenshot.sh and patches/serpantinum/files/clipboard/
  # localsend.py read those variables directly.
  xdg.userDirs.setSessionVariables = true;

  services.playerctld.enable = true;

  home.packages = [
    pkgs.openvpn
    pkgs.update-systemd-resolved
    # pkgs.python312
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
