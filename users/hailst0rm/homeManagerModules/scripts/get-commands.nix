{
  pkgs,
  lib,
  config,
  ...
}: let
  getCommandsScript = ''
    # Paths to the configuration files
    nixos_file="${config.home.homeDirectory}/.nixos/nixosModules/system/utils.nix"
    home_manager_file="${config.home.homeDirectory}/.nixos/users/${config.username}/homeManagerModules/utils.nix"

    # Combine the contents of both files
    content=$(cat "$nixos_file" "$home_manager_file" 2>/dev/null)

    # Extract package names and comments
    packages=$(echo "$content" | grep -oP '(?<=pkgs\.|pkgs-unstable\.)\S+(?:\s*#.*)?' | grep -vP ';')

    # Format the output: command followed by comment
    formatted=$(echo "$packages" | sed -E 's/\s*#\s*/ - /' | sed -E 's/ *$//')

    # Display the formatted list
    echo "$formatted"
  '';

  getCommands = pkgs.writeScriptBin "get-commands" getCommandsScript;
in {
  options.scripts.get-commands.enable = lib.mkEnableOption "Enable get-commands script.";

  config = {
    home.packages = lib.mkIf config.scripts.get-commands.enable [getCommands];
  };
}
