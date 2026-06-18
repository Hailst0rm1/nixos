{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  # Ctrl+N -> Ctrl+K, but only inside Discord. Discord's QuickSwitcher is
  # hard-bound to Ctrl+K internally and can't be remapped there, while the
  # global Ctrl+K is taken by Hyprland's vim-arrow Up remap. sendshortcut
  # delivers the synthetic combo straight to the focused window without
  # re-entering Hyprland's bind dispatcher, so the global Ctrl+K stays intact.
  # Everywhere else Ctrl+N is passed through unchanged.
  discord-quickswitch = pkgs.writeShellScript "discord-quickswitch" ''
    class=$(hyprctl activewindow -j | ${pkgs.jq}/bin/jq -r '.class')
    case "$class" in
      discord)
        hyprctl dispatch sendshortcut "CTRL, K,"
        ;;
      *)
        hyprctl dispatch sendshortcut "CTRL, N,"
        ;;
    esac
  '';
in {
  imports = [inputs.nixcord.homeModules.nixcord];

  config = lib.mkIf config.applications.discord.enable {
    programs.nixcord = {
      enable = true; # enable Nixcord. Also installs discord package
      #quickCss = "some CSS";  # quickCSS file
      config = {
        #useQuickCss = true;   # use out quickCSS
        themeLinks = [
          # or use an online theme
          "https://raw.githubusercontent.com/catppuccin/discord/refs/heads/main/themes/mocha.theme.css"
        ];
        #frameless = true; # set some Vencord options
        plugins = {
          fakeNitro.enable = true;
          #hideAttachments.enable = true;    # Enable a Vencord plugin
          #ignoreActivities = {    # Enable a plugin and set some options
          #enable = true;
          #ignorePlaying = true;
          #ignoreWatching = true;
          #ignoredActivities = [ "someActivity" ];
          #};
        };
      };
      #extraConfig = {
      # Some extra JSON config here
      # ...
      #};
    };

    # Reach Discord's Ctrl+K QuickSwitcher via Ctrl+N (only when Hyprland is
    # the WM). Appends to the bind list defined in the Hyprland module.
    wayland.windowManager.hyprland.settings.bind = lib.mkIf config.importConfig.hyprland.enable [
      "CTRL, N, exec, ${discord-quickswitch}"
    ];
  };
}
