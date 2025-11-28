{
  pkgs,
  pkgs-unstable,
  ...
}: {
  # Module served to install default utils and applications on the system

  nix.settings = {
    substituters = ["https://devenv.cachix.org"];
    trusted-public-keys = ["devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="];
  };

  # Zsh
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;
  environment.pathsToLink = ["/share/zsh"];

  environment.systemPackages = [
    # Basic tooling
    pkgs.zsh
    pkgs.bash
    pkgs.vim
    pkgs.curl
    pkgs.wget
    pkgs.p7zip
    pkgs.unzip
    pkgs.zip
    pkgs.file
    pkgs.jq
    pkgs.xclip
    pkgs.dig
    pkgs.expect

    # Git
    pkgs.git
    pkgs.gh
    pkgs.lazygit # TUI

    # Improved Version of Normal Tooling
    pkgs-unstable.bat # Cat: with syntax highlight + git
    pkgs-unstable.lsd # Ls: improved
    pkgs-unstable.ripgrep # Grep: Fast recursive
    pkgs.bat-extras.batgrep # Bat+Ripgrep
    pkgs-unstable.fd # Find: Fast & ux
    pkgs-unstable.zoxide # Cd: smart
    pkgs-unstable.dust # Du: Fast disk space utility
    pkgs-unstable.gdu # Du: TUI
    # pkgs-unstable.bottom # Top/htop: Fast + better
    pkgs-unstable.htop # Top improved
    pkgs-unstable.procs # Ps: Fast + ux
    pkgs-unstable.tealdeer # Man: Simplified and practical examples
    pkgs-unstable.httpie # Curl/wget: UX for REST API
    pkgs-unstable.sd # Sed: UX and fast
    pkgs-unstable.difftastic # Diff: Side by side, UX
    pkgs-unstable.nh # Nixos-rebuild: Short + pretty
    pkgs-unstable.nix-init # Generate nix package from URL
  ];
}
