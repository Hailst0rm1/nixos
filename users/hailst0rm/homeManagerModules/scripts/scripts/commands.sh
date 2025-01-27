#!/usr/bin/env bash

# Paths to the configuration files
nixos_file=~/.nixos/nixosModules/system/utils.nix
home_manager_file=~/.nixos/users/$USER/homeManagerModules/utils.nix

# Combine the contents of both files
content=$(cat "$nixos_file" "$home_manager_file")

# Extract package names and comments
packages=$(echo "$content" | grep -oP '(?<=pkgs\.|pkgs-unstable\.)\S+(?:\s*#.*)?' | grep -vP ';')

# Format the output: command followed by comment
formatted=$(echo "$packages" | sed -E 's/\s*#\s*/ - /' | sed -E 's/ *$//')

# Display the formatted list in rofi
echo "$formatted" | rofi -dmenu -theme-str 'window {width: 50%;} listview {columns: 1;}'

