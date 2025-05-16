{ pkgs, lib, config, ... }:

let
  keymap = pkgs.writeText "keymap.xkb" ''
    partial alphanumeric_keys
    xkb_symbols "colemak-se" {

    	    include "se(basic)"

	    name[Group1]="Colemak-SE";

	    // top row
	    key <AD03> { [ f, F ] };
	    key <AD04> { [ p, P ] };
	    key <AD05> { [ g, G ] };
	    key <AD06> { [ j, J ] };
	    key <AD07> { [ l, L ] };
	    key <AD08> { [ u, U ] };
	    key <AD09> { [ y, Y ] };
	    key <AD10> { [ odiaeresis, Odiaeresis ] };
	    key <AD11> { [ aring, Aring ] };

	    // home row
	    key <AC02> { [ r, R ] };
	    key <AC03> { [ s, S ] };
	    key <AC04> { [ t, T ] };
	    key <AC05> { [ d, D ] };
	    key <AC06> { [ h, H ] };
	    key <AC07> { [ n, N ] };
	    key <AC08> { [ e, E ] };
	    key <AC09> { [ i, I ] };
	    key <AC10> { [ o, O ] };

	    // bottom row
	    key <AB06> { [ k, K ] };

    };
  '';
in
{
  options.system.keyboard.colemak-se = lib.mkEnableOption "Enable the colemak-se layout";

  config = lib.mkIf config.system.keyboard.colemak-se {
    # Colemak-SE for boot
    console = lib.mkIf config.system.keyboard.colemak-se {
      earlySetup = true;
      useXkbConfig = true;
    };

    environment.etc."X11/xkb/keymap.xkb".source = keymap;

    # Ensure home-manager doesn't interfere with XKB
    home-manager.users.hailst0rm = {
      home.keyboard = null;
    };

    services.xserver = {
      enable = true;
      xkb = {
        extraLayouts.colemak-se = {
          description = "Colemak-SE";
          languages   = [ "swe" ];
          symbolsFile = keymap;
        };
        layout = "colemak-se";
        model = "pc105";
        variant = "";
      };
    };
  };
}
