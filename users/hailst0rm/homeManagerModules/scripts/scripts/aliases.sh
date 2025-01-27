#!/usr/bin/env bash

config_file=~/.config/zsh/.zshrc

aliases=$(grep -oP '(?<=alias -- ).*' $config_file)
aliases=$(echo "$aliases" | sed 's/=/ = /')

rofi -dmenu -theme-str 'window {width: 50%;} listview {columns: 1;}' <<< "$aliases"
