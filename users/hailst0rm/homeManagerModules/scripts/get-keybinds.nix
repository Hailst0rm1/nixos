{ pkgs, lib, config, ... }:

let
  getKeybindsScript = ''
    config_file="${config.home.homeDirectory}/.config/hypr/hyprland.conf"
    keybinds=$(grep -oP '(?<=bind=).*' $config_file)
    keybinds=$(echo "$keybinds" | sed 's/,\([^,]*\)$/ = \1/' | sed 's/, exec//g' | sed 's/^,//g')
    rofi -dmenu -theme-str 'window {width: 50%;} listview {columns: 1;}' <<< "$keybinds"
  '';

  hyprlandEnabled = config.importConfig.hyprland.enable;
  getKeybinds = pkgs.writeScriptBin "get-keybinds" getKeybindsScript;
in {
  config = {
    home.packages = lib.mkIf hyprlandEnabled [ getKeybinds ];
  };
}

