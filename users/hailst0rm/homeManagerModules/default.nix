{
  config,
  lib,
  username,
  hostname,
  ...
}: {
  programs = {
    home-manager.enable = true;
  };

  home = {
    stateVersion = "24.11";
    username = lib.mkDefault "${username}";
    homeDirectory = lib.mkDefault "/home/${username}";
  };

  imports = [
    # Default utils
    ./git.nix
    ./helix.nix
    ./kitty.nix
    ./utils.nix
    ./yazi.nix
    ./zsh.nix
    ./stylix.nix
    ./scripts/scripts.nix


    # Default applications
    ../../applications/bitwarden-desktop.nix
    ../../applications/discord.nix
    ../../applications/obsidian.nix
    ../../applications/proton-mail.nix
    ../../applications/proton-vpn.nix
    ../../applications/spotify.nix

    # If desktop active
    ./hyprland/default.nix
  ];
}
