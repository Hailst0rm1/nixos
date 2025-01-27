{ pkgs, ... }:
let
  get-keybinds = pkgs.writeScriptBin "get-keybinds" (
    builtins.readFile ./scripts/keybinds.sh
  );
  get-alias = pkgs.writeScriptBin "get-alias" (
    builtins.readFile ./scripts/aliases.sh
  );
  get-commands = pkgs.writeScriptBin "get-commands" (
    builtins.readFile ./scripts/commands.sh
  );
  help = pkgs.writeScriptBin "help" (
    builtins.readFile ./scripts/help.sh
  );
in {
  home.packages = with pkgs; [
    get-keybinds
    get-alias
    get-commands
    help
  ];
}
