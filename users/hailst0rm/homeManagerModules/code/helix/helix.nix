{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}: {
  options.code.helix.enable = lib.mkEnableOption "Enable Helix";

  config = lib.mkIf (config.editor == "hx" || config.editor == "helix" || config.code.helix.enable) {
    programs.helix = {
      enable = true;
      package = pkgs-unstable.helix;
      defaultEditor = true;

      settings = {
        theme = "catppuccin_mocha";
        editor = {
          shell = ["zsh" "-c"];
          line-number = "relative";
          cursorline = true;
          idle-timeout = 1;
          completion-replace = true;
          true-color = true;
          color-modes = true;
          bufferline = "always";
          # rulers = [ 100 ];
          popup-border = "all";
          soft-wrap.enable = true;

          lsp = {
            display-messages = true;
            display-inlay-hints = true;
          };

          cursor-shape = {
            normal = "block";
            insert = "bar";
            select = "underline";
          };

          indent-guides = {
            render = true;
            character = "╎";
          };

          gutters = ["diagnostics" "line-numbers" "spacer" "diff"];
          statusline = {
            separator = "<U+E0BC>";
            left = ["mode" "selections" "spinner" "file-name" "total-line-numbers"];
            center = [];
            right = ["diagnostics" "file-encoding" "file-line-ending" "file-type" "position-percentage" "position"];
            mode = {
              normal = "NORMAL";
              insert = "INSERT";
              select = "SELECT";
            };
          };
        };
        keys.normal = {
          "X" = "extend_line_above";
          "C-q" = ":bc";
          "C-d" = ["half_page_down" "align_view_center"];
          "C-u" = ["half_page_up" "align_view_center"];
        };
      };

      extraPackages = with pkgs; [
        # Code assistant
        helix-gpt

        # Nix Formatting
        alejandra

        # Debugging stuff
        lldb

        # Default Language servers
        nil # Nix
        nodePackages.yaml-language-server # YAML / JSON
      ];
    };
  };
}
