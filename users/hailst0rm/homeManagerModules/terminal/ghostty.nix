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
        font-size = lib.mkForce 12;
        window-decoration = false;

        # New windows are a GTK activation of the running instance instead of a
        # cold process fork, so they skip the ~1-2s GTK+EGL/shader re-init that
        # otherwise stacks on top of iGPU contention (mpvpaper + Hyprland blur +
        # other Wayland clients) and shows as a stuck blurred window on open.
        gtk-single-instance = true;

        # Finishes the job the preBuild sed above starts. That sed only
        # reaches src/renderer/generic.zig, which imports libxev's static
        # default backend (io_uring on Linux) and so cannot be steered at
        # runtime. Everything else goes through src/global.zig's
        # xev.Dynamic, which `auto` resolves to io_uring on this kernel —
        # the running instance holds 8 io_uring fds. So the renderer ran on
        # epoll while the app and IO loops ran on io_uring, and a surface
        # whose io_uring setup stalls comes up as a window that never paints.
        async-backend = "epoll";

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
