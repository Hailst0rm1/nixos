#!/usr/bin/env bash

# Capture per-monitor screenshots in parallel (like hyprlock's "path = screenshot")
# This avoids the wrong-crop issue of a single full grim capture
for output in $(hyprctl monitors -j 2>/dev/null | jq -r '.[].name'); do
    grim -o "$output" "/tmp/lock_bg_${output}.png" &
done
wait

quickshell -p ~/.config/quickshell/Lock.qml
