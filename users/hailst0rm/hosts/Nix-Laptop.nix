{ lib, config, ...}:
let
  # Lib 
  myLib = import ../../../myLib/generators.nix;
in {
  imports = [
    myLib.validFiles ../homeManagerModules
    myLib.validFiles ../../applications
    #../../../hosts/Nix-Laptop/configuration.nix


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


  # Inherit variables from system
  

  terminal = "ghostty";
  shell = "zsh";
  editor = "hx";
  fileManager = "nautilus";
  browser = "firefox";
  video = "totem";
  image = "loupe";
  keyboardLayout = "colemak-se";

  tools = {
    
  };

  applications = {
    
  };
  

  # Git
  #gitUsername = "Hailst0rm1";
  #gitEmail = "hailst0rm1@proton.me"
}

