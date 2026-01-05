{
  pkgs,
  lib,
  config,
  username,
  hostname,
  nixosDir,
  hostPlatform,
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
    stateVersion = "25.11";
    username = lib.mkDefault "${config.username}";
    homeDirectory = lib.mkDefault "/home/${config.username}";
    enableNixpkgsReleaseCheck = lib.mkDefault false;
  };

  # NIXOS Variables.nix (inherited from system config)
  username = username;
  hostname = hostname;
  nixosDir = nixosDir;
  # Note: hostPlatform is available as a function argument, not set as an option
  # Access it directly in your config where needed (e.g., hostPlatform)
  myLocation = myLocation;
  laptop = laptop;

  # Variables.nix (mainly used for zsh-environment)
  terminal = lib.mkDefault "ghostty";
  shell = lib.mkDefault "zsh";
  editor = lib.mkDefault "hx";
  fileManager = lib.mkDefault "nautilus";
  browser = lib.mkDefault "firefox";
  video = lib.mkDefault "totem";
  image = lib.mkDefault "loupe";
  keyboard = lib.mkDefault "colemak-se,se";

  # Import configuration for other tools
  importConfig = {
    git.enable = lib.mkDefault true;
    ssh.enable = lib.mkDefault true;
    yazi.enable = lib.mkDefault true;
    stylix.enable = lib.mkDefault true;
    sops.enable = lib.mkDefault sops;
    zsh-history-sync.enable = lib.mkDefault true;
    hyprland = {
      enable = lib.mkDefault true;
      customScreenPicker = lib.mkDefault true;
      accentColour = lib.mkDefault "green";
      panel = lib.mkDefault "hyprpanel";
      lockscreen = lib.mkDefault "hyprlock";
      appLauncher = lib.mkDefault "rofi";
      notifications = lib.mkDefault "hyprpanel";
      wallpaper = lib.mkDefault "swww";
      monitorOrientations = lib.mkDefault {
        "0" = "left";
        "1" = "left";
      };
    };
  };

  # IDE for coding
  code = {
    claude-code.enable = lib.mkDefault false;
    helix = {
      enable = lib.mkDefault true;
      languages = {
        cpp = lib.mkDefault false;
        cSharp = lib.mkDefault false;
        python = lib.mkDefault false;
        rust = lib.mkDefault false;
        web = lib.mkDefault false;
      };
    };
    vscode = {
      enable = lib.mkDefault true;
      languages = {
        cpp = lib.mkDefault false;
        python = lib.mkDefault false;
        rust = lib.mkDefault false;
      };
    };
  };

  applications = {
    bitwarden.enable = lib.mkDefault true;
    brave.enable = lib.mkDefault false;
    discord.enable = lib.mkDefault true;
    firefox.enable = lib.mkDefault true;
    gpt4all.enable = lib.mkDefault false;
    libreOffice.enable = lib.mkDefault true;
    mattermost.enable = lib.mkDefault false;
    obsidian.enable = lib.mkDefault true;
    remmina.enable = lib.mkDefault true;
    spotify.enable = lib.mkDefault true;
    youtube-music.enable = lib.mkDefault false;
    zen-browser.enable = lib.mkDefault false;
    claude-desktop.enable = lib.mkDefault true;
    openconnect.enable = lib.mkDefault false;
    espanso.enable = lib.mkDefault false;
    aws-cvpn-wrapper.enable = lib.mkDefault false;
    proton = {
      enableAll = lib.mkDefault true;
      mail.enable = lib.mkDefault false;
      vpn.enable = lib.mkDefault false;
      pass.enable = lib.mkDefault false;
      authenticator.enable = lib.mkDefault false;
    };
    games = {
      ryujinx.enable = lib.mkDefault false;
    };
  };

  cyber = {
    malwareAnalysis.enable = lib.mkDefault false;
    redTools.enable = lib.mkDefault redTools;
  };
}
