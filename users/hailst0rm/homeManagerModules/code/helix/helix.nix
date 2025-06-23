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
        keys = {
          normal = {
            # Faster navigation: Move paragraphs with Ctrl
            "C-j" = ["goto_next_paragraph" "collapse_selection"];
            "C-k" = ["goto_prev_paragraph" "collapse_selection"];

            # Newlines without insert
            "o" = ["open_below" "normal_mode"];
            "O" = ["open_above" "normal_mode"];

            # Add half page
            "g" = {
              "k" = "page_cursor_half_up";
              "j" = "page_cursor_half_down";
            };

            # Make beginning/end of line more intuitive with H/L
            "H" = ["goto_first_nonwhitespace" "collapse_selection"];
            "L" = ["goto_line_end"];

            # Personal preferenses
            "m" = "match_brackets";
            "S" = "surround_add"; # Would be nice to be able to do something after this but it isn't chainable
            "Q" = "replay_macro";

            # Clipboards over registers
            "x" = "delete_selection";
            "p" = ["paste_clipboard_after" "collapse_selection"];
            "P" = ["paste_clipboard_before" "collapse_selection"];

            # Restoring VIM functionality
            "V" = ["select_mode" "extend_to_line_bounds"];
            "C" = ["extend_to_line_end" "yank_main_selection_to_clipboard" "delete_selection" "insert_mode"];
            "D" = ["extend_to_line_end" "yank_main_selection_to_clipboard" "delete_selection"];
            "Y" = ["extend_to_line_end" "yank_main_selection_to_clipboard" "collapse_selection"];
            "w" = ["move_next_word_start" "move_char_right" "collapse_selection"];
            "W" = ["move_next_long_word_start" "move_char_right" "collapse_selection"];
            "e" = ["move_next_word_end" "collapse_selection"];
            "E" = ["move_next_long_word_end" "collapse_selection"];
            "b" = ["move_prev_word_start" "collapse_selection"];
            "B" = ["move_prev_long_word_start" "collapse_selection"];
            "f" = ["find_next_char" "collapse_selection"];
            "F" = ["find_prev_char" "collapse_selection"];
            "t" = ["find_till_char" "collapse_selection"];
            "T" = ["till_prev_char" "collapse_selection"];
            "u" = ["undo" "collapse_selection"];
            "esc" = ["collapse_selection" "keep_primary_selection"];
            "/" = ["search" "select_mode"];
            "?" = ["rsearch" "select_mode"];
            "%" = ["select_all" "select_mode"];
            # Consider commenting these out to explore native Helix selection movement
            "i" = ["insert_mode" "collapse_selection"];
            "a" = ["append_mode" "collapse_selection"];
            "q" = "record_macro";
            # Search for word under cursor
            "*" = ["move_char_right" "move_prev_word_start" "move_next_word_end" "search_selection" "search_next"];
            "#" = ["move_char_right" "move_prev_word_start" "move_next_word_end" "search_selection" "search_prev"];

            d = {
              "d" = ["extend_to_line_bounds" "yank_main_selection_to_clipboard" "delete_selection"];
              "t" = ["extend_till_char"];
              "s" = ["surround_delete"];
              "a" = ["select_textobject_around"];
              "j" = ["select_mode" "extend_to_line_bounds" "extend_line_below" "yank_main_selection_to_clipboard" "delete_selection" "normal_mode"];
              "k" = ["select_mode" "extend_to_line_bounds" "extend_line_above" "yank_main_selection_to_clipboard" "delete_selection" "normal_mode"];

              "i" = {
                "w" = ["move_prev_word_start" "collapse_selection" "move_next_word_start" "yank_main_selection_to_clipboard" "delete_selection"];
                "W" = ["move_prev_long_word_start" "collapse_selection" "move_next_long_word_start" "yank_main_selection_to_clipboard" "delete_selection"];
                "p" = ["goto_prev_paragraph" "collapse_selection" "select_mode" "goto_next_paragraph" "yank_main_selection_to_clipboard" "delete_selection"];
                "b" = ["match_brackets" "collapse_selection" "select_mode" "match_brackets" "yank_main_selection_to_clipboard" "delete_selection"];
              };
            };

            c = {
              "c" = ["extend_to_line_bounds" "yank_main_selection_to_clipboard" "change_selection"];
              "t" = ["extend_till_char"];
              "s" = ["surround_delete"];
              "a" = ["select_textobject_around"];
              "j" = ["select_mode" "extend_to_line_bounds" "extend_line_below" "yank_main_selection_to_clipboard" "change_selection" "normal_mode"];
              "k" = ["select_mode" "extend_to_line_bounds" "extend_line_above" "yank_main_selection_to_clipboard" "change_selection" "normal_mode"];

              "i" = {
                "w" = ["move_prev_word_start" "collapse_selection" "move_next_word_start" "yank_main_selection_to_clipboard" "change_selection"];
                "W" = ["move_prev_long_word_start" "collapse_selection" "move_next_long_word_start" "yank_main_selection_to_clipboard" "change_selection"];
                "p" = ["goto_prev_paragraph" "collapse_selection" "select_mode" "goto_next_paragraph" "yank_main_selection_to_clipboard" "change_selection"];
                "b" = ["match_brackets" "collapse_selection" "select_mode" "match_brackets" "yank_main_selection_to_clipboard" "change_selection"];
              };
            };

            y = {
              "y" = ["extend_to_line_bounds" "yank_main_selection_to_clipboard" "normal_mode" "collapse_selection"];
              "j" = ["select_mode" "extend_to_line_bounds" "extend_line_below" "yank_main_selection_to_clipboard" "collapse_selection" "normal_mode"];
              "a" = ["select_textobject_around"];
              "k" = ["select_mode" "extend_to_line_bounds" "extend_line_above" "yank_main_selection_to_clipboard" "collapse_selection" "normal_mode"];

              "i" = {
                "w" = ["move_prev_word_start" "collapse_selection" "move_next_word_start" "yank_main_selection_to_clipboard" "collapse_selection" "normal_mode"];
                "W" = ["move_prev_long_word_start" "collapse_selection" "move_next_long_word_start" "yank_main_selection_to_clipboard" "collapse_selection" "normal_mode"];
                "p" = ["goto_prev_paragraph" "collapse_selection" "select_mode" "goto_next_paragraph" "yank_main_selection_to_clipboard"];
                "b" = ["match_brackets" "collapse_selection" "select_mode" "match_brackets" "yank_main_selection_to_clipboard"];
              };
            };
          };

          insert = {
            "esc" = ["collapse_selection" "normal_mode"];
            "C-c" = ["collapse_selection" "normal_mode"];
            "C-n" = ["collapse_selection" "normal_mode"];
            "C-a" = ["goto_line_end"];
            "C-i" = ["goto_first_nonwhitespace"];
            "C-b" = ["move_prev_word_start"];
            "C-w" = ["move_next_word_start"];
            "C-l" = ["move_char_right"];
            "C-h" = ["move_char_left"];
            "C-d" = ["delete_char_forward"];
            "C-u" = ["undo"];
            "C-y" = ["redo"];
          };

          select = {
            # Personal preferences
            "m" = "match_brackets";
            "S" = "surround_add";

            # Faster navigation
            "C-j" = ["goto_next_paragraph"];
            "C-k" = ["goto_prev_paragraph"];

            # Keep helix g-movement but make "h" non-whitespace
            "g" = {
              "k" = "page_cursor_half_up";
              "j" = "page_cursor_half_down";
            };

            # Make beginning/end of line more intuitive with H/L
            "H" = "goto_first_nonwhitespace";
            "L" = "goto_line_end";

            # Restore VIM functionality (kinda)
            "D" = ["extend_to_line_bounds" "delete_selection" "normal_mode"];
            "Y" = ["extend_to_line_bounds" "yank_main_selection_to_clipboard" "goto_line_start" "collapse_selection" "normal_mode"];
            "C" = ["goto_line_start" "extend_to_line_bounds" "change_selection"];
            "u" = ["switch_to_lowercase" "collapse_selection" "normal_mode"];
            "U" = ["switch_to_uppercase" "collapse_selection" "normal_mode"];
            "k" = ["extend_line_up" "extend_to_line_bounds"];
            "j" = ["extend_line_down" "extend_to_line_bounds"];
            "d" = ["yank_main_selection_to_clipboard" "delete_selection"];
            "x" = ["yank_main_selection_to_clipboard" "delete_selection"];
            "y" = ["yank_main_selection_to_clipboard" "normal_mode" "flip_selections" "collapse_selection"];
            "p" = "replace_selections_with_clipboard";
            "P" = "paste_clipboard_before";

            "i" = "select_textobject_inner";
            "a" = "select_textobject_around";

            "tab" = ["insert_mode" "collapse_selection"];
            "C-a" = ["append_mode" "collapse_selection"];

            # Add remove selection with "v"
            "esc" = ["collapse_selection" "keep_primary_selection" "normal_mode"];
            "v" = ["collapse_selection" "keep_primary_selection" "normal_mode"];

            # Search like in vim
            "n" = ["collapse_selection" "search_next"];
            "N" = ["collapse_selection" "search_prev"];
          };
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
