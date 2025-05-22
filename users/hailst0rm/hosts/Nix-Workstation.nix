{
  lib,
  config,
  username,
  hostname,
  nixosDir,
  systemArch,
  myLocation,
  laptop,
  redTools,
  ...
}: let
  # Lib
  myLib = import ../../../lib/generators.nix;
in {
  imports =
    [
      ../../applications.nix
      ../../../nixosModules/variables.nix
    ]
    ++ lib.filter
    (n: lib.strings.hasSuffix ".nix" n)
    (lib.filesystem.listFilesRecursive ../homeManagerModules);

  programs = {
    home-manager.enable = true;
  };

  home = {
    stateVersion = "24.11";
    username = lib.mkDefault "${config.username}";
    homeDirectory = lib.mkDefault "/home/${config.username}";
  };

  # NIXOS Variables.nix (inherited from system config)
  username = username;
  hostname = hostname;
  nixosDir = nixosDir;
  systemArch = systemArch;
  myLocation = myLocation;
  laptop = laptop;

  # HM Variables.nix (mainly used for zsh-environment)
  terminal = "ghostty";
  shell = "zsh";
  editor = "hx";
  fileManager = "nautilus";
  browser = "firefox";
  video = "totem";
  image = "loupe";
  keyboard = "colemak-se,se";

  # Import configuration for other tools
  importConfig = {
    git.enable = true;
    yazi.enable = true;
    stylix.enable = true;
    hyprland = {
      enable = true;
      panel = "hyprpanel";
      lockscreen = "hyprlock";
      appLauncher = "rofi";
      notifications = "hyprpanel";
      wallpaper = "swww";
    };
  };

  applications = {
    bitwarden.enable = true;
    discord.enable = true;
    firefox.enable = true;
    libreOffice.enable = true;
    mattermost.enable = true;
    obsidian.enable = true;
    proton.enableAll = true;
    remmina.enable = true;
    spotify.enable = true;
    zen-browser.enable = true;
    vscode.enable = true;
    games = {
      ryujinx.enable = true;
    };
  };

  cyber = {
    malwareAnalysis.enable = false;
    redTools.enable = lib.mkDefault redTools;
  };
}
