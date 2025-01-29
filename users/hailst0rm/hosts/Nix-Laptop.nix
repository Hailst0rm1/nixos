{ lib, config, ...}:
let
  # Lib 
  myLib = import ../../../myLib/generators.nix;
in {
  imports = [
    myLib.validFiles ../homeManagerModules
    ../../applications.nix

    # Keep for now but delete later
    ../homeManagerModules/default.nix
    ../homeManagerModules/zen-browser.nix

    # Switch emulator
    ../../applications/games/ryujinx.nix
  ];

  programs = {
    home-manager.enable = true;
  };

  home = {
    stateVersion = "24.11";
    username = lib.mkDefault "${config.username}";
    homeDirectory = lib.mkDefault "/home/${config.username}";
  };

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
    mattermost.enable = true;
    obsidian.enable = true;
    proton-all.enable = true;
    spotify.enable = true;
    zen-browser.enable = true;
    proton.enableAll = true;
    games = {
      ryujinx.enable = true;
    };
  };

  scripts = {
    get-commands.enable = true;
    get-alias.enable = true;
    # Bind the other to hyprland.enable
  };
}

