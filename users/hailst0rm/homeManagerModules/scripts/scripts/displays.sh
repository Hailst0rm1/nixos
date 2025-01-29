DIR="$HOME/.nixos/users/$USER/hosts/displays"
FILE="$DIR/$HOST.conf"

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
  # Process the file content
  {
  echo -n '[ '
  grep '^monitor=' "$FILE" | sed -E 's/^monitor=(.*)$/"\1"/' | tr '\n' ' ' | sed 's/ $/ ]/'
  } > "$FILE.tmp"

  # Replace the original file with the processed one
  mv "$FILE.tmp" "$FILE"
fi

# Reload Hyprland
hyprctl reload 1>/dev/null
