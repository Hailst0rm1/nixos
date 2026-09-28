final: prev: {
  # The groupbar lights a tab only when its window holds global focus, so an
  # unfocused group shows every tab dimmed and hides which one is current.
  # Key the active colour off the group's current window instead.
  hyprland = prev.hyprland.overrideAttrs (old: {
    patches =
      (old.patches or [])
      ++ [
        ../patches/hyprland/0001-groupbar-highlight-current-when-unfocused.patch
      ];
  });
}
