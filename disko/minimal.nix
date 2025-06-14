{ config, lib, pkgs, ... }:let
  username = "hailst0rm";
  device = "nvme0n1"; # IMPORTANT Set disk device (e.g. "sda", or "nvme0n1") - list with `lsblk`
  keymap = pkgs.writeText "keymap.xkb" ''
    partial alphanumeric_keys
    xkb_symbols "colemak-se" {

    	    include "se(basic)"

     name[Group1]="Colemak-SE";

     // top row
     key <AD03> { [ f, F ] };
     key <AD04> { [ p, P ] };
     key <AD05> { [ g, G ] };
     key <AD06> { [ j, J ] };
     key <AD07> { [ l, L ] };
     key <AD08> { [ u, U ] };
     key <AD09> { [ y, Y ] };
     key <AD10> { [ odiaeresis, Odiaeresis ] };
     key <AD11> { [ aring, Aring ] };

     // home row
     key <AC02> { [ r, R ] };
     key <AC03> { [ s, S ] };
     key <AC04> { [ t, T ] };
     key <AC05> { [ d, D ] };
     key <AC06> { [ h, H ] };
     key <AC07> { [ n, N ] };
     key <AC08> { [ e, E ] };
     key <AC09> { [ i, I ] };
     key <AC10> { [ o, O ] };

     // bottom row
     key <AB06> { [ k, K ] };

    };
  '';
in {
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
       "${builtins.fetchTarball "https://github.com/nix-community/disko/archive/master.tar.gz"}/module.nix"
      ./disko.nix 
      {
        _module.args.device = device; # Sets the installation disk on disko-install
      }

    ];

  # Use the grub boot loader
  boot.loader = {
    grub = {
      enable = true;
      efiSupport = true;
      enableCryptodisk = true;
    };
    efi.canTouchEfiVariables = true;
    efi.efiSysMountPoint = "/boot";
    supportedFilesystems = {
      ntfs = true;
      btrfs = true;
      luks = true;
    };
    extraModprobeConfig = ''
      options snd slots=snd-hda-intel
    '';
  };

  networking.hostName = "nixos"; # Define your hostname.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Set your time zone.
  time.timeZone = "Europe/Stockholm";

  # Enable gnome
  services.xserver = {
    desktopManager.gnome.enable = true;
    displayManager.gdb.enable = true;
  };

  # Configure keymap in X11
  console = lib.mkIf config.system.keyboard.colemak-se {
    earlySetup = true;
    useXkbConfig = true;
  };

  environment.etc."X11/xkb/keymap.xkb".source = keymap;
  services.xserver = {
    enable = true;
    xkb = {
      extraLayouts.colemak-se = {
        description = "Colemak-SE";
        languages = ["swe"];
        symbolsFile = keymap;
      };
      layout = "colemak-se";
      model = "pc105";
      variant = "";
    };
  };

  # Bluetooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = false;

  # Allow unfree software
  nixpkgs.config.allowUnfree = true;

  # Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";

  # User account
  users = {
    users.${username} = {
      isNormalUser = true;
      extraGroups = [
        "sudo"
        "networkmanager"
        "wheel"
      ];
      initialPassword = "t";
    };
  };

  # Cache
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    substituters = ["https://devenv.cachix.org"];
    trusted-public-keys = ["devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="];
  };

  # Default apps and utils
  programs.firefox.enable = true;
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

    # Git
    pkgs.git
    pkgs.gh
    pkgs.lazygit # TUI

    # Improved Version of Normal Tooling
    pkgs.bat # Cat: with syntax highlight + git
    pkgs.lsd # Ls: improved
    pkgs.ripgrep # Grep: Fast recursive
    pkgs.bat-extras.batgrep # Bat+Ripgrep
    pkgs.fd # Find: Fast & ux
    pkgs.zoxide # Cd: smart
    pkgs.du-dust # Du: Fast disk space utility
    pkgs.gdu # Du: TUI
    pkgs.bottom # Top/htop: Fast + better
    pkgs.procs # Ps: Fast + ux
    pkgs.tealdeer # Man: Simplified and practical examples
    pkgs.httpie # Curl/wget: UX for REST API
    pkgs.sd # Sed: UX and fast
    pkgs.difftastic # Diff: Side by side, UX
    pkgs.nh # Nixos-rebuild: Short + pretty
  ];


  # Don't change
  system.stateVersion = "25.05"; # Did you read the comment?
}
