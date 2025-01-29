{ lib, ... }:

{
  options = {
    terminal = lib.mkOption {
      type = lib.types.str;
      default = "kitty";
      description = "The default terminal emulator.";
    };

    shell = lib.mkOption {
      type = lib.types.str;
      default = "zsh";
      description = "The default shell.";
    };

    editor = lib.mkOption {
      type = lib.types.str;
      default = "vim";
      description = "The default text editor.";
    };

    fileManager = lib.mkOption {
      type = lib.types.str;
      default = "nautilus";
      description = "The default file manager.";
    };

    browser = lib.mkOption {
      type = lib.types.str;
      default = "firefox";
      description = "The default web browser.";
    };

    video = lib.mkOption {
      type = lib.types.str;
      default = "totem";
      description = "The default video player.";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "loupe";
      description = "The default image viewer.";
    };

    keyboard = lib.mkOption {
      type = lib.types.str;
      default = "se";
      description = "The default keyboard layout.";
    };
  };
}
