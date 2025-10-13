{
  pkgs,
  lib,
  config,
  username,
  hostname,
  nixosDir,
  systemArch,
  myLocation,
  laptop,
  redTools,
  sops,
  ...
}: {
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
    stateVersion = "25.05";
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

  # Variables.nix (mainly used for zsh-environment)
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
    ssh.enable = true;
    yazi.enable = true;
    stylix.enable = true;
    sops.enable = sops;
    zsh-history-sync.enable = true;
    hyprland = {
      enable = true;
      customScreenPicker = true;
      accentColour = "red";
      panel = "hyprpanel";
      lockscreen = "hyprlock";
      appLauncher = "rofi";
      notifications = "hyprpanel";
      wallpaper = "swww";
      monitorOrientations = {
        "0" = "top";
        "1" = "left";
      };
    };
  };

  # IDE for coding
  code = {
    helix = {
      enable = true;
      languages = {
        cpp = false;
        cSharp = false;
        python = false;
        rust = false;
        web = false;
      };
    };
    vscode = {
      enable = true;
      languages = {
        cpp = false;
        python = false;
        rust = false;
      };
    };
  };

  applications = {
    bitwarden.enable = true;
    discord.enable = true;
    firefox.enable = true;
    gpt4all.enable = false;
    libreOffice.enable = true;
    mattermost.enable = false;
    obsidian.enable = true;
    proton.enableAll = true;
    remmina.enable = true;
    spotify.enable = true;
    youtube-music.enable = true;
    zen-browser.enable = false;
    claude-desktop.enable = true;
    openconnect.enable = true;
    espanso.enable = false;
    games = {
      ryujinx.enable = false;
    };
  };

  cyber = {
    malwareAnalysis.enable = false;
    redTools.enable = lib.mkDefault redTools;
  };
}
