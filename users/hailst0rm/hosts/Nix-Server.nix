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
  fileManager = "";
  browser = "";
  video = "";
  image = "";
  keyboard = "colemak-se,se";

  # Import configuration for other tools
  importConfig = {
    git.enable = true;
    ssh.enable = true;
    yazi.enable = true;
    stylix.enable = false;
    sops.enable = sops;
    zsh-history-sync.enable = true;
    hyprland = {
      enable = false;
      accentColour = "pink";
      panel = "hyprpanel";
      lockscreen = "hyprlock";
      appLauncher = "rofi";
      notifications = "hyprpanel";
      wallpaper = "swww";
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
      enable = false;
      languages = {
        cpp = false;
        python = false;
        rust = false;
      };
    };
  };

  applications = {
    bitwarden.enable = false;
    discord.enable = false;
    firefox.enable = false;
    gpt4all.enable = false;
    libreOffice.enable = false;
    mattermost.enable = false;
    obsidian.enable = false;
    proton.enableAll = false;
    remmina.enable = false;
    spotify.enable = false;
    zen-browser.enable = false;
    openconnect.enable = false;
    games = {
      ryujinx.enable = false;
    };
  };

  cyber = {
    malwareAnalysis.enable = false;
    redTools.enable = lib.mkDefault redTools;
  };
}
