{ pkgs, lib, config, username, hostname, nixosDir, systemArch, myLocation, laptop, ...}:
let
  # Lib 
  myLib = import ../../../myLib/generators.nix;
in {
  imports = [
    ../../applications.nix
    ../../../nixosModules/variables.nix
  ] ++ lib.filter 
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
    gpt4all.enable = true;
    libreOffice.enable = true;
    mattermost.enable = true;
    obsidian.enable = true;
    proton.enableAll = true;
    remmina.enable = true;
    spotify.enable = true;
    zen-browser.enable = true;
    games = {
      ryujinx.enable = true;
    };
  };

  scripts = {
    get-commands.enable = true;
    get-alias.enable = true;
  };
}

