final: prev: {
  hyprpanel = prev.hyprpanel.overrideAttrs (oldAttrs: {
    postPatch =
      (oldAttrs.postPatch or "")
      + ''
            # Add Colemak-SE to the keyboard layout map so hyprpanel displays it correctly
            substituteInPlace src/components/bar/modules/kblayout/helpers/layouts.ts \
              --replace-fail "'Unknown Layout': 'Unknown'," "'Colemak-SE': 'CM-SE',
        'Unknown Layout': 'Unknown',"
      '';
  });
}
