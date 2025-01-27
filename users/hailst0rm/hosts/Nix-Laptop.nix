{...}: {
  imports = [
    # Default utils and applications
    ../homeManagerModules/default.nix
    ../homeManagerModules/zen-browser.nix

    # Switch emulator
    ../../applications/games/ryujinx.nix
  ];

  #editor = "hx";
  #terminal = "kitty";
  #fileManager = "nautilus";
  #browser = "zen";
  #video = 
  #keyboardLayout = "colemak-se";
  #

  # Git
  #gitUsername = "Hailst0rm1";
  #gitEmail = "hailst0rm1@proton.me"
}

