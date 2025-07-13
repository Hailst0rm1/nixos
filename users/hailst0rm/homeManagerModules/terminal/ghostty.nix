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
        keybind = [
          "ctrl+shift+j=scroll_page_down"
          "ctrl+shift+k=scroll_page_up"
          "super+shift+h=adjust_selection:left"
          "super+shift+l=adjust_selection:right"
          "super+shift+k=adjust_selection:up"
          "super+shift+j=adjust_selection:down"
          "ctrl+p=paste_from_clipboard"
          "ctrl+y=copy_to_clipboard"
          "super+shift+o=new_split:right"
        ];
      };
    };
  };
}
