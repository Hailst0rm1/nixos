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
          # Quick iteration on config changes
          "C-o" = ":config-open";
          "C-r" = ":config-reload";

          # Some nice Helix stuff
          "C-h" = "select_prev_sibling";
          "C-j" = "shrink_selection";
          "C-k" = "expand_selection";
          "C-l" = "select_next_sibling";

          # Personal preference
          "o" = ["open_below" "normal_mode"];
          "O" = ["open_above" "normal_mode"];

          # Muscle memory
          "{" = ["goto_prev_paragraph" "collapse_selection"];
          "}" = ["goto_next_paragraph" "collapse_selection"];
          "0" = "goto_line_start";
          "$" = "goto_line_end";
          "^" = "goto_first_nonwhitespace";
          "G" = "goto_file_end";
          "%" = "match_brackets";
          "V" = ["select_mode" "extend_to_line_bounds"];
          "C" = ["extend_to_line_end" "yank_main_selection_to_clipboard" "delete_selection" "insert_mode"];
          "D" = ["extend_to_line_end" "yank_main_selection_to_clipboard" "delete_selection"];
          "S" = "surround_add"; # Would be nice to be able to do something after this but it isn't chainable

          # Clipboards over registers ye ye
          "x" = "delete_selection";
          "p" = ["paste_clipboard_after" "collapse_selection"];
          "P" = ["paste_clipboard_before" "collapse_selection"];
          # Would be nice to add ya and yi, but the surround commands can't be chained
          "Y" = ["extend_to_line_end" "yank_main_selection_to_clipboard" "collapse_selection"];

          # Uncanny valley stuff, this makes w and b behave as they do Vim
          "w" = ["move_next_word_start" "move_char_right" "collapse_selection"];
          "W" = ["move_next_long_word_start" "move_char_right" "collapse_selection"];
          "e" = ["move_next_word_end" "collapse_selection"];
          "E" = ["move_next_long_word_end" "collapse_selection"];
          "b" = ["move_prev_word_start" "collapse_selection"];
          "B" = ["move_prev_long_word_start" "collapse_selection"];

          # Consider commenting these out to explore native Helix selection movement
          "i" = ["insert_mode" "collapse_selection"];
          "a" = ["append_mode" "collapse_selection"];

          # Undoing the 'd' + motion commands restores the selection which is annoying
          "u" = ["undo" "collapse_selection"];

          # Escape the madness! No more fighting with the cursor! Or with multiple cursors!
          "esc" = ["collapse_selection" "keep_primary_selection"];

          # Search for word under cursor
          "*" = ["move_char_right" "move_prev_word_start" "move_next_word_end" "search_selection" "search_next"];
          "#" = ["move_char_right" "move_prev_word_start" "move_next_word_end" "search_selection" "search_prev"];

          # Make j and k behave as they do Vim when soft-wrap is enabled
          "j" = "move_line_down";
          "k" = "move_line_up";

          d = {
            d = ["extend_to_line_bounds" "yank_main_selection_to_clipboard" "delete_selection"];
            t = ["extend_till_char"];
            s = ["surround_delete"];
            i = ["select_textobject_inner"];
            a = ["select_textobject_around"];
            j = ["select_mode" "extend_to_line_bounds" "extend_line_below" "yank_main_selection_to_clipboard" "delete_selection" "normal_mode"];
            down = ["select_mode" "extend_to_line_bounds" "extend_line_below" "yank_main_selection_to_clipboard" "delete_selection" "normal_mode"];
            k = ["select_mode" "extend_to_line_bounds" "extend_line_above" "yank_main_selection_to_clipboard" "delete_selection" "normal_mode"];
            up = ["select_mode" "extend_to_line_bounds" "extend_line_above" "yank_main_selection_to_clipboard" "delete_selection" "normal_mode"];
            G = ["select_mode" "extend_to_line_bounds" "goto_last_line" "extend_to_line_bounds" "yank_main_selection_to_clipboard" "delete_selection" "normal_mode"];
            w = ["move_next_word_start" "yank_main_selection_to_clipboard" "delete_selection"];
            W = ["move_next_long_word_start" "yank_main_selection_to_clipboard" "delete_selection"];
            g.g = ["select_mode" "extend_to_line_bounds" "goto_file_start" "extend_to_line_bounds" "yank_main_selection_to_clipboard" "delete_selection" "normal_mode"];
          };

          y = {
            y = ["extend_to_line_bounds" "yank_main_selection_to_clipboard" "normal_mode" "collapse_selection"];
            j = ["select_mode" "extend_to_line_bounds" "extend_line_below" "yank_main_selection_to_clipboard" "collapse_selection" "normal_mode"];
            down = ["select_mode" "extend_to_line_bounds" "extend_line_below" "yank_main_selection_to_clipboard" "collapse_selection" "normal_mode"];
            k = ["select_mode" "extend_to_line_bounds" "extend_line_above" "yank_main_selection_to_clipboard" "collapse_selection" "normal_mode"];
            up = ["select_mode" "extend_to_line_bounds" "extend_line_above" "yank_main_selection_to_clipboard" "collapse_selection" "normal_mode"];
            G = ["select_mode" "extend_to_line_bounds" "goto_last_line" "extend_to_line_bounds" "yank_main_selection_to_clipboard" "collapse_selection" "normal_mode"];
            w = ["move_next_word_start" "yank_main_selection_to_clipboard" "collapse_selection" "normal_mode"];
            W = ["move_next_long_word_start" "yank_main_selection_to_clipboard" "collapse_selection" "normal_mode"];
            g.g = ["select_mode" "extend_to_line_bounds" "goto_file_start" "extend_to_line_bounds" "yank_main_selection_to_clipboard" "collapse_selection" "normal_mode"];
          };
        };

        insert = {
          esc = ["collapse_selection" "normal_mode"];
        };

        select = {
          # Muscle memory
          "{" = ["extend_to_line_bounds" "goto_prev_paragraph"];
          "}" = ["extend_to_line_bounds" "goto_next_paragraph"];
          "0" = "goto_line_start";
          "$" = "goto_line_end";
          "^" = "goto_first_nonwhitespace";
          "G" = "goto_file_end";
          "D" = ["extend_to_line_bounds" "delete_selection" "normal_mode"];
          "C" = ["goto_line_start" "extend_to_line_bounds" "change_selection"];
          "%" = "match_brackets";
          "S" = "surround_add";
          "u" = ["switch_to_lowercase" "collapse_selection" "normal_mode"];
          "U" = ["switch_to_uppercase" "collapse_selection" "normal_mode"];

          i = "select_textobject_inner";
          a = "select_textobject_around";

          tab = ["insert_mode" "collapse_selection"];
          "C-a" = ["append_mode" "collapse_selection"];

          k = ["extend_line_up" "extend_to_line_bounds"];
          j = ["extend_line_down" "extend_to_line_bounds"];

          d = ["yank_main_selection_to_clipboard" "delete_selection"];
          x = ["yank_main_selection_to_clipboard" "delete_selection"];
          y = ["yank_main_selection_to_clipboard" "normal_mode" "flip_selections" "collapse_selection"];
          Y = ["extend_to_line_bounds" "yank_main_selection_to_clipboard" "goto_line_start" "collapse_selection" "normal_mode"];
          p = "replace_selections_with_clipboard";
          P = "paste_clipboard_before";

          esc = ["collapse_selection" "keep_primary_selection" "normal_mode"];
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
