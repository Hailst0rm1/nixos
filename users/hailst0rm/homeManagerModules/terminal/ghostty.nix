{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}: {
  config = lib.mkIf (config.terminal == "ghostty") {
    programs.ghostty = {
      enable = true;
      package = pkgs.ghostty.overrideAttrs (_: {
        doCheck = false;
        preBuild = ''
          shopt -s globstar
          sed -i 's/^const xev = @import("xev");$/const xev = @import("xev").Epoll;/' **/*.zig
          shopt -u globstar
        '';
      });
      enableZshIntegration = true;
      settings = {
        font-size = lib.mkForce 14;
        window-decoration = false;

        # Use the regular clipboard for copy-on-select so everything goes to the same place
        clipboard-paste-bracketed-safe = true;

        keybind = [
          "ctrl+shift+j=scroll_page_down"
          "ctrl+shift+k=scroll_page_up"
          "super+shift+h=adjust_selection:left"
          "super+shift+l=adjust_selection:right"
          "super+shift+k=adjust_selection:up"
          "super+shift+j=adjust_selection:down"
          "ctrl+p=paste_from_clipboard"
          "ctrl+y=copy_to_clipboard"
          "alt+v=paste_from_clipboard"
          "alt+c=copy_to_clipboard"
          # Hyprland sends Ctrl+Shift+C/V via sendshortcut for mainmod+c/v
          "ctrl+shift+c=copy_to_clipboard"
          "super+shift+o=new_split:right"
          "ctrl+enter=unbind"
        ];
      };
    };
  };
}
