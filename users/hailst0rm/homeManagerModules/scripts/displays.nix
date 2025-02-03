{ pkgs, lib, config, ... }:

let
  displaysScript = ''
    DIR="${config.home.homeDirectory}/.nixos/users/${config.username}/hosts/displays"
    FILE="$DIR/${config.hostname}.conf"

    # Create the directory if it doesn't exist
    if [[ ! -d "$DIR" ]]; then
        mkdir -p "$DIR"
    fi

    # Create the file if it doesn't exist
    if [[ ! -f "$FILE" ]]; then
        touch "$FILE"
        # Set file permissions
        sudo chmod 755 "$FILE"
    fi

    # Inform user about script
    echo "[!] The monitors will refresh once you close the GUI application - not once you've applied the settings in GUI"

    # Run nwg-displays
    nwg-displays -m $FILE &>/dev/null

    # Modify the file after nwg-displays exits
    if [[ -f "$FILE" ]]; then
      {
        echo -n '[ '
        grep '^monitor=' "$FILE" | sed -E 's/^monitor=(.*)$/"\1"/' | tr '\n' ' ' | sed 's/ $/ ]/'
      } > "$FILE.tmp"
      mv "$FILE.tmp" "$FILE"
    fi

    # Reload Hyprland
    hyprctl reload 1>/dev/null
  '';

  displays = pkgs.writeScriptBin "displays" displaysScript;

  ## Check if Hyprland is enabled
  hyprlandEnabled = config.importConfig.hyprland.enable;
in {
  config = {
    home.packages = lib.mkIf hyprlandEnabled [ displays ];
  };
}

