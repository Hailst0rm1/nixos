{ pkgs, lib, config, ... }:

let
  get-alias = pkgs.writeScriptBin "get-alias" (
    builtins.readFile ./scripts/aliases.sh
  );
  get-commands = pkgs.writeScriptBin "get-commands" (
    builtins.readFile ./scripts/commands.sh
  );

  ## Hyprland specific
  displays = pkgs.writeScriptBin "displays" (
    builtins.readFile ./scripts/displays.sh
  );
  get-keybinds = pkgs.writeScriptBin "get-keybinds" (
    builtins.readFile ./scripts/keybinds.sh
  );
  help = pkgs.writeScriptBin "help" (
    builtins.readFile ./scripts/help.sh
  );

  ## Check if Hyprland is enabled
  hyprlandEnabled = config.importConfig.hyprland.enable;
in {
  options = {
    scripts.get-commands.enable = lib.mkEnableOption "Enable get-commands script.";
    scripts.get-alias.enable = lib.mkEnableOption "Enable get-alias script.";
  };

  config = {
    # Conditional enabling of packages based on script options and Hyprland enablement
    home.packages = with pkgs; lib.mkMerge [
      (lib.mkIf (config.scripts.get-commands.enable) [ get-commands ])
      (lib.mkIf (config.scripts.get-alias.enable) [ get-alias ])
      (lib.mkIf hyprlandEnabled [ help get-keybinds displays ])
    ];

    # Additional settings
    wayland.windowManager.hyprland.settings.bind = lib.mkIf hyprlandEnabled [ "$mainMod, F1, exec, get-keybinds" ];
  };
}

