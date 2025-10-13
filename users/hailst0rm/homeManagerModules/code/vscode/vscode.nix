{
  config,
  pkgs,
  pkgs-unstable,
  lib,
  ...
}: let
  cfg = config.code.vscode;
in {
  options.code.vscode.enable = lib.mkEnableOption "Enable VS Code";

  # Todo:
  # - MCP server?

  config = lib.mkIf cfg.enable {
    # VS Code setup
    home.packages = with pkgs; [
      nixd
      alejandra

      powershell

      shellcheck
      shfmt
    ];

    programs = {
      # Create a shell.nix / default.nix in project directory to use nix shell environment
      direnv = {
        enable = true;
        enableZshIntegration = true;
        nix-direnv.enable = true;
      };
      zsh.initContent = ''
        eval "$(direnv hook zsh)"
      '';

      vscode = {
        enable = true;
        package = pkgs-unstable.vscode;

        profiles.default = {
          # https://marketplace.visualstudio.com/
          extensions = with pkgs.vscode-marketplace; [
            # === Nix ===
            jnoortheen.nix-ide # Nix language support - syntax highlighting, formatting, and error reporting.
            kamadorueda.alejandra # Code formatter
            mkhl.direnv # Load / Unload nix shell development

            # === PowerShell ===
            ms-vscode.powershell

            # === Bash ===
            mads-hartmann.bash-ide-vscode

            # === AI ===
            github.copilot # AI code assistant
            github.copilot-chat # AI code assistant
            anthropic.claude-code # Claude Code AI assistant

            # === Functionality ===
            eamodio.gitlens # Git + insights
            ms-vscode.live-server # Live web application preview
            wix.vscode-import-cost # Display import/require package size in the editor
            formulahendry.code-runner # Run code or parts of code
            ms-vsliveshare.vsliveshare # Collaborative VSCode
            vscodevim.vim # Vim keybindings
            formulahendry.auto-rename-tag # Auto rename paired HTML/XML tags
            orta.vscode-jest # Jest testing
            firsttris.vscode-jest-runner # Inline Jest test runner
            donjayamanne.githistory # Git history UI

            # === Appearence ===
            esbenp.prettier-vscode # Formatter: JS,TS,JSON,CSS,MD,YAML,HTML,etc.
            pkief.material-icon-theme # Cute icons
            mechatroner.rainbow-csv # CSV colour
            usernamehw.errorlens # Highlight errors and warnings
          ];

          # Optional: Use VS Code Insiders instead of stable
          # package = pkgs.vscode-insiders;

          userSettings = {
            "workbench.iconTheme" = "material-icon-theme";

            "files.autoSave" = "afterDelay";
            "files.autoSaveDelay" = 100;

            "editor.suggest.insertMode" = "replace";
            "editor.cursorBlinking" = "smooth";
            "editor.cursorSurroundingLines" = 4;
            "editor.formatOnSave" = true;
            "editor.linkedEditing" = true;
            "editor.lineNumbers" = "relative";
            "editor.wordWrap" = "on";
            "editor.inlineSuggest.enabled" = true;
            "editor.minimap.enabled" = false;
            "breadcrumbs.enabled" = false;

            "zenMode.hideLineNumbers" = false;
            "zenMode.hideTabs" = false;

            "nix.enableLanguageServer" = true;
            "nix.serverPath" = "nixd";
            "nix.serverSettings" = {
              "nixd" = {
                "formatting" = {"command" = ["alejandra"];};
                # "options" = {
                #   # By default, this entry will be read from `import <nixpkgs> { }`.
                #   # You can write arbitary Nix expressions here, to produce valid "options" declaration result.
                #   # Tip: for flake-based configuration, utilize `builtins.getFlake`
                #   "nixos" = {
                #     "expr" = "(builtins.getFlake \"/synced/Nix/cfg\").nixosConfigurations.<name>.options";
                #   };
                #   "home-manager" = {
                #     "expr" = "(builtins.getFlake \"/synced/Nix/cfg\").homeConfigurations.<name>.options";
                #   };
                # };
              };
            };

            "vim.leader" = "<Space>";
            "vim.useSystemClipboard" = true;
            "vim.hlsearch" = true;
            "vim.incsearch" = true;
            "vim.normalModeKeyBindingsNonRecursive" = [
              # Tab switch
              {
                "before" = ["leader" "<Tab>"];
                "commands" = [":bnext"];
              }
              {
                "before" = ["leader" "<S-Tab>"];
                "commands" = [":bprevious"];
              }

              # Go to tab nr X
              {
                "before" = ["leader" "1"];
                "commands" = ["workbench.action.openEditorAtIndex1"];
              }
              {
                "before" = ["leader" "2"];
                "commands" = ["workbench.action.openEditorAtIndex2"];
              }
              {
                "before" = ["leader" "3"];
                "commands" = ["workbench.action.openEditorAtIndex3"];
              }
              {
                "before" = ["leader" "4"];
                "commands" = ["workbench.action.openEditorAtIndex4"];
              }
              {
                "before" = ["leader" "5"];
                "commands" = ["workbench.action.openEditorAtIndex5"];
              }
              {
                "before" = ["leader" "6"];
                "commands" = ["workbench.action.openEditorAtIndex6"];
              }
              {
                "before" = ["leader" "7"];
                "commands" = ["workbench.action.openEditorAtIndex7"];
              }
              {
                "before" = ["leader" "8"];
                "commands" = ["workbench.action.openEditorAtIndex8"];
              }
              {
                "before" = ["leader" "9"];
                "commands" = ["workbench.action.openEditorAtIndex9"];
              }

              # Toggle comment selection
              {
                "before" = ["leader" "c"];
                "commands" = ["editor.action.commentLine"];
              }

              # Format document
              {
                "before" = ["leader" "f"];
                "commands" = ["editor.action.formatDocument"];
              }

              # Open settings
              {
                "before" = ["leader" "s"];
                "commands" = ["workbench.action.openSettings"];
              }

              # Open file explorer
              {
                "before" = ["leader" "e"];
                "commands" = ["workbench.view.explorer"];
              }

              # Open terminal
              {
                "before" = ["leader" "t"];
                "commands" = ["workbench.action.terminal.toggleTerminal"];
              }

              # Open inline copilot
              {
                "before" = ["leader" "i"];
                "commands" = ["inlineChat.start"];
              }

              # Open command palette
              {
                "before" = ["leader" "p"];
                "commands" = ["workbench.action.showCommands"];
              }

              # Close file
              {
                "before" = ["leader" "q"];
                "commands" = [":q!"];
              }

              # Window navigation
              {
                "before" = ["leader" "h"];
                "commands" = ["workbench.action.focusLeftGroup"];
              }
              {
                "before" = ["leader" "j"];
                "commands" = ["workbench.action.focusBelowGroup"];
              }
              {
                "before" = ["leader" "k"];
                "commands" = ["workbench.action.focusAboveGroup"];
              }
              {
                "before" = ["leader" "l"];
                "commands" = ["workbench.action.focusRightGroup"];
              }

              # Split window
              {
                "before" = ["leader" "S-v"];
                "commands" = [":vsplit"];
              }
              {
                "before" = ["leader" "S-h"];
                "commands" = [":split"];
              }

              # Search for files
              {
                "before" = ["leader" "s"];
                "commands" = ["workbench.action.quickOpen"];
              }

              # Find in files
              {
                "before" = ["leader" "S-s"];
                "commands" = ["workbench.action.findInFiles"];
              }

              # Move by visual lines
              {
                "before" = ["j"];
                "after" = ["g" "j"];
              }
              {
                "before" = ["k"];
                "after" = ["g" "k"];
              }

              # Beginning and end of line
              {
                "before" = ["H"];
                "after" = ["^"];
              }
              {
                "before" = ["L"];
                "after" = ["$"];
              }

              # End of file
              {
                "before" = ["g" "e"];
                "after" = ["G"];
              }

              # Paragraph movement
              {
                "before" = ["<C-k>"];
                "after" = ["{"];
              }
              {
                "before" = ["<C-j>"];
                "after" = ["}"];
              }
              # Redo with U
              {
                "before" = ["U"];
                "after" = ["<C-r>"];
              }

              # Matching bracket
              {
                "before" = ["m"];
                "after" = ["%"];
              }

              # Select entire file with %
              {
                "before" = ["%"];
                "after" = ["g" "g" "V" "G"];
              }

              # Don't enter visual mode with o/O
              {
                "before" = ["o"];
                "after" = ["o" "<Esc>"];
              }
              {
                "before" = ["O"];
                "after" = ["O" "<Esc>"];
              }

              # Access recording with Q
              {
                "before" = ["@"];
                "after" = ["Q"];
              }
            ];

            "vim.insertModeKeyBindings" = [
              # Escape insert with Ctrl+n
              {
                "before" = ["<C-n>"];
                "after" = ["<Esc>"];
              }

              # Emacs-style navigation in insert mode
              {
                "before" = ["<C-h>"];
                "after" = ["<Esc>" "i"];
              }
              {
                "before" = ["<C-l>"];
                "after" = ["<Esc>" "l" "a"];
              }
              {
                "before" = ["<C-a>"];
                "after" = ["<Esc>" "$" "a"];
              }
              {
                "before" = ["<C-i>"];
                "after" = ["<Esc>" "^" "i"];
              }
              {
                "before" = ["<C-b>"];
                "after" = ["<Esc>" "b" "i"];
              }
              {
                "before" = ["<C-w>"];
                "after" = ["<Esc>" "w" "a"];
              }
              {
                "before" = ["<C-e>"];
                "after" = ["<Esc>" "e" "a"];
              }
              {
                "before" = ["<C-d>"];
                "after" = ["<Esc>" "l" "d" "l" "i"];
              }
              {
                "before" = ["<C-u>"];
                "after" = ["<Esc>" "u" "i"];
              }
              {
                "before" = ["<C-y>"];
                "after" = ["<Esc>" "<C-r>" "i"];
              }
            ];

            "vim.visualModeKeyBindings" = [
              # Escape visual with v
              {
                "before" = ["v"];
                "after" = ["<Esc>"];
              }

              # Open inline copilot
              {
                "before" = ["leader" "i"];
                "commands" = ["inlineChat.start"];
              }

              # Move by visual lines
              {
                "before" = ["j"];
                "after" = ["g" "j"];
              }
              {
                "before" = ["k"];
                "after" = ["g" "k"];
              }

              # Beginning and end of line
              {
                "before" = ["H"];
                "after" = ["^"];
              }
              {
                "before" = ["L"];
                "after" = ["$"];
              }

              # End of file
              {
                "before" = ["g" "e"];
                "after" = ["G"];
              }

              # Paragraph movement
              {
                "before" = ["<C-k>"];
                "after" = ["{"];
              }
              {
                "before" = ["<C-j>"];
                "after" = ["}"];
              }

              # Stay in visual mode after in-/outdenting
              {
                "before" = ["<"];
                "commands" = ["editor.action.outdentLines"];
              }
              {
                "before" = [">"];
                "commands" = ["editor.action.indentLines"];
              }

              # Move selected lines while staying in visual mode
              {
                "before" = ["J"];
                "commands" = ["editor.action.moveLinesDownAction"];
              }
              {
                "before" = ["K"];
                "commands" = ["editor.action.moveLinesUpAction"];
              }

              # Toggle comment selection
              {
                "before" = ["leader" "c"];
                "commands" = ["editor.action.commentLine"];
              }
            ];
          };

          #

          # https://code.visualstudio.com/docs/configure/keybindings#_advanced-customization%20%20%20%20%20%20%20%20{
          keybindings = [
            # Copilot
            {
              key = "ctrl+shift+i";
              command = "workbench.panel.chat.view.copilot.focus";
            }
            # Uncfocus copilot
            {
              key = "ctrl+shift+i";
              command = "workbench.action.focusActiveEditorGroup";
              when = "!editorFocus";
            }
            # Accept next word
            {
              key = "ctrl+l";
              command = "editor.action.inlineSuggest.acceptNextWord";
              when = "inlineSuggestionVisible && !accessibilityModeEnabled && !editorReadonly";
            }
            # Accept entire suggestion
            {
              key = "ctrl+shift+l";
              command = "editor.action.inlineSuggest.commit";
              when = "inlineSuggestionVisible && !accessibilityModeEnabled && !editorReadonly";
            }

            # Explorer shortcuts
            {
              key = "space e";
              command = "workbench.action.toggleSidebarVisibility";
              when = "filesExplorerFocus && !inputFocus";
            }
            {
              key = "a";
              command = "explorer.newFile";
              when = "explorerViewletVisible && filesExplorerFocus && !explorerResourceIsRoot && !explorerResourceReadonly && !inputFocus";
            }
            {
              key = "f";
              command = "explorer.newFolder";
              when = "explorerViewletVisible && filesExplorerFocus && !explorerResourceIsRoot && !explorerResourceReadonly && !inputFocus";
            }
            {
              key = "r";
              command = "renameFile";
              when = "explorerViewletVisible && filesExplorerFocus && !explorerResourceIsRoot && !explorerResourceReadonly && !inputFocus";
            }
            {
              key = "x";
              command = "filesExplorer.cut";
              when = "explorerViewletVisible && filesExplorerFocus && !explorerResourceIsRoot && !explorerResourceReadonly && !inputFocus";
            }
            {
              key = "y";
              command = "filesExplorer.copy";
              when = "explorerViewletVisible && filesExplorerFocus && !inputFocus";
            }
            {
              key = "p";
              command = "filesExplorer.paste";
              when = "explorerViewletVisible && filesExplorerFocus && !explorerResourceReadonly && !inputFocus";
            }

            # Terminal shortcuts
            {
              key = "ctrl+shift+n";
              command = "workbench.action.togglePanel";
            }
            {
              key = "ctrl+shift+t";
              command = "workbench.action.terminal.new";
              when = "terminalFocus";
            }
            {
              key = "ctrl+shift+q";
              command = "workbench.action.terminal.kill";
              when = "terminalFocus";
            }
            {
              key = "ctrl+shift+h";
              command = "workbench.action.terminal.focusPrevious";
              when = "terminalFocus";
            }
            {
              key = "ctrl+shift+l";
              command = "workbench.action.terminal.focusNext";
              when = "terminalFocus";
            }

            # Unbinds
            {
              key = "ctrl+b";
              command = "-workbench.action.toggleSidebarVisibility";
            }
          ];
          # userMcp = {
          #   servers = {
          #     nixos = {
          #       command = "nix";
          #       args = ["run" "github:utensils/mcp-nixos" "--"];
          #     };
          #     github = {
          #       url = "https://api.githubcopilot.com/mcp/";
          #     };
          #   };
          # };
        };
      };
    };
  };
}
