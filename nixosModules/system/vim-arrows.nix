{
  lib,
  config,
  ...
}: {
  options.system.keyboard.vim-arrows =
    lib.mkEnableOption "Remap Ctrl+hjkl to arrow keys at the evdev level via keyd";

  config = lib.mkIf config.system.keyboard.vim-arrows {
    # keyd rewrites keys below the compositor, so Hyprland and every client
    # (including layer-shell popups) see a real, genuinely-held arrow key —
    # taps and hold-to-repeat both work, which no Hyprland bind mechanism
    # managed (see docs/research/vim-arrow-keybindings.md).
    #
    # keyd sits below xkb, so keys are named by physical (QWERTY) position:
    # Colemak-SE puts j/k/l on the y/n/u positions (h stays put).
    services.keyd = {
      enable = true;
      keyboards.default = {
        ids = ["*"];
        settings = {
          main = {};
          control = {
            h = "left";
            y = "down";
            n = "up";
            u = "right";
          };
        };
        # Composite layers must be defined after the layers they are built
        # from, hence extraConfig (appended after settings).
        extraConfig = ''
          # Word-step: Ctrl+Shift+h/l -> Ctrl+Left/Right (was a Hyprland
          # sendshortcut bind, which never reached layer-shell popups).
          # Unmapped keys pass through untouched, so Ctrl+Shift+j/k survive.
          [control+shift]
          h = C-left
          u = C-right

          # Keep Super+Ctrl+hjkl intact for Hyprland's resizeactive binds —
          # without this layer keyd would turn them into Super+arrows.
          [meta+control]
          h = M-C-h
          y = M-C-y
          n = M-C-n
          u = M-C-u
        '';
      };
    };

    # Every keypress now arrives from keyd's virtual keyboard; without this
    # quirk libinput no longer counts them as typing and the touchpad's
    # disable-while-typing stops working.
    environment.etc."libinput/local-overrides.quirks".text = ''
      [Serial Keyboards]
      MatchUdevType=keyboard
      MatchName=keyd*virtual*keyboard
      AttrKeyboardIntegration=internal
    '';
  };
}
