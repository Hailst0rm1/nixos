{ pkgs, lib, config, ... }:

let
  getAliasScript = ''
    config_file="${config.home.homeDirectory}/.config/zsh/.zshrc"

    aliases=$(grep -oP '(?<=alias -- ).*' $config_file)
    aliases=$(echo "$aliases" | sed 's/=/ = /')

    rofi -dmenu -theme-str 'window {width: 50%;} listview {columns: 1;}' <<< "$aliases"
  '';

  getAlias = pkgs.writeScriptBin "get-alias" getAliasScript;
in {
  options.scripts.get-alias.enable = lib.mkEnableOption "Enable get-alias script.";

  config = {
    home.packages = lib.mkIf config.scripts.get-alias.enable [ getAlias ];
  };
}
