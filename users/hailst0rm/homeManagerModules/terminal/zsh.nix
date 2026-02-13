{
  pkgs,
  pkgs-unstable,
  config,
  lib,
  ...
}: {
  config = lib.mkIf (config.shell == "zsh") {
    home.file = {
      ".local/share/zsh/zinit".source = "${pkgs.zinit}/share/zinit";
      ".local/share/zsh/zinit".recursive = true;
      ".local/share/zsh/fzf".source = "${pkgs.fzf}/share/fzf";
    };

    programs.zsh = {
      enable = true;
      #enableCompletion = true;
      #autosuggestion.enable = true;
      #syntaxHighlighting.enable = true;
      dotDir = "${config.home.homeDirectory}/.config/zsh";

      history = {
        size = 10000;
        extended = true;
        path = "${config.xdg.dataHome}/zsh/history";
      };

      oh-my-zsh = {
        enable = true;
        plugins = ["git" "sudo" "aws"];
      };

      envExtra = ''
        export TERMINAL="${config.terminal}"
        export TERM="${config.terminal}"
        export EDITOR="${config.editor}"
        export BROWSER="${config.browser}"
        export VIDEO="${config.video}"
        export IMAGE="${config.image}"
        export OPENER="xdg-open"
        export LAUNCHER="${
          if config.importConfig.hyprland.enable
          then config.importConfig.hyprland.appLauncher
          else ""
        }"
        export FLAKE="${config.nixosDir}" # For nh
        export GIT_EXTERNAL_DIFF="difft" # Using difftastic for git diffs
        export ZINIT_HOME="$HOME/.local/share/zsh/zinit"
        export FZF_DEFAULT_OPTS="--color=16"
        export FZF_DEFAULT_OPTS=" \
        --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
        --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
        --color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
        --color=selected-bg:#45475a \
        --multi"
      '';

      shellAliases = {
        sudo = "sudo ";
        ".." = "cd ..";
        c = "wl-copy";
        p = "wl-paste";
        cl = "clear";
        q = "exit";
        s = "source";
        ":q" = "exit";
        nix-edit = "yazi ${config.nixosDir}";
        yz = "yazi";

        # Modern commands
        ls = "lsd";
        la = "lsd -lah";
        tree = "lsd --tree -a";
        cat = "bat -pp";
        lat = "bat -p";
        less = "bat";
        lgit = "lazygit";
        ldocker = "lazydocker";
        ljournal = "lazyjournal";
        du = "dust";
        top = "bottom";
        pss = "procs";
        diff = "difft";
      };

      initContent = ''
        ${pkgs-unstable.fastfetch}/bin/fastfetch

        clean () {
          echo "Deleting all but 5 NixOS generations..."
          sudo ${pkgs.nh}/bin/nh clean all -k 5
        }

        # Mkdir + cd dir
        ckdir () {
          mkdir -p "$1" && cd "$1"
        }

        # Realpath with copy to clipboard
        rp () {
          local result=$(realpath "$@")
          echo "$result" | wl-copy
          echo "$result"
        }

        # Pushes config to git wherever you are
        nix-push() {
          git -C ~/.nixos push "$@"
        }

        # Pull config to git wherever you are
        nix-pull() {
          git -C ~/.nixos pull "$@"
        }

        # Unalias gp from oh-my-zsh git plugin so our function can be defined
        unalias gp 2>/dev/null

        # Interactive git commit and push
        gp() {
          local red='\033[0;31m'
          local green='\033[0;32m'
          local yellow='\033[0;33m'
          local blue='\033[0;34m'
          local magenta='\033[0;35m'
          local cyan='\033[0;36m'
          local white='\033[0;37m'
          local bold='\033[1m'
          local reset='\033[0m'

          echo -e "''${cyan}''${bold}🔍 Git Status Check''${reset}\n"

          # Check if there are any changes to commit
          if [[ -z $(git status --porcelain) ]]; then
            echo -e "''${green}✓ Nothing to commit, working tree clean.''${reset}"

            # Check if behind remote
            git fetch origin &>/dev/null
            local behind=$(git rev-list HEAD..@{u} --count 2>/dev/null)
            if [[ -n "$behind" && "$behind" -gt 0 ]]; then
              echo -e "''${yellow}⚠ Your branch is behind remote by $behind commit(s).''${reset}"
              printf "''${yellow}Pull changes? [y/N]: ''${reset}"
              read -r pull_confirm
              if [[ "$pull_confirm" =~ ^[Yy]$ ]]; then
                git pull
              fi
            else
              echo -e "''${green}✓ Branch is up to date with remote.''${reset}"
            fi
            return 0
          fi

          # Show changed files with colors
          echo -e "''${bold}📝 Changed files:''${reset}\n"
          git status --short | while IFS= read -r line; do
            local file_status="''${line:0:2}"
            local file="''${line:3}"
            case "$file_status" in
              "M "*|" M") echo -e "  ''${yellow}● Modified:''${reset} $file" ;;
              "A "*|" A") echo -e "  ''${green}+ Added:''${reset} $file" ;;
              "D "*|" D") echo -e "  ''${red}✗ Deleted:''${reset} $file" ;;
              "R "*|" R") echo -e "  ''${magenta}➜ Renamed:''${reset} $file" ;;
              "??") echo -e "  ''${cyan}? Untracked:''${reset} $file" ;;
              *) echo -e "  ''${white}$file_status''${reset} $file" ;;
            esac
          done

          # Check if behind remote
          echo ""
          git fetch origin &>/dev/null
          local behind=$(git rev-list HEAD..@{u} --count 2>/dev/null)
          if [[ -n "$behind" && "$behind" -gt 0 ]]; then
            echo -e "''${yellow}⚠ Warning: Your branch is behind remote by $behind commit(s).''${reset}"
            printf "''${yellow}Continue anyway? [y/N]: ''${reset}"
            read -r continue_confirm
            if [[ ! "$continue_confirm" =~ ^[Yy]$ ]]; then
              echo -e "''${red}Aborted.''${reset}"
              return 1
            fi
          fi

          # Ask for commit message
          echo ""
          echo -e "''${bold}''${blue}💬 Commit Message''${reset}"
          printf "''${blue}➜ ''${reset}"
          read -r msg
          if [[ -z "$msg" ]]; then
            echo -e "''${red}✗ Commit message cannot be empty.''${reset}"
            return 1
          fi

          # Show summary and confirm
          echo ""
          echo -e "''${bold}''${magenta}📋 Summary''${reset}"
          echo -e "''${magenta}Commit:''${reset} $msg"
          echo ""
          printf "''${green}Commit and push? [Y/n]: ''${reset}"
          read -r confirm
          if [[ "$confirm" =~ ^[Nn]$ ]]; then
            echo -e "''${red}✗ Aborted.''${reset}"
            return 1
          fi

          # Execute git commands
          echo ""
          git add -A && \
          git commit -m "$msg" && \
          git push && \
          echo -e "\n''${green}''${bold}✓ Successfully committed and pushed!''${reset}" || \
          echo -e "\n''${red}''${bold}✗ Failed to commit and push.''${reset}"
        }

        # Source/Load Zinit
        source "''${ZINIT_HOME}/zinit.zsh" 2>/dev/null

        # Load completions
        #autoload -Uz compinit && compinit

        # Add in zsh plugins
        zinit light zsh-users/zsh-completions # Command flag completions
        zinit light Aloxaf/fzf-tab # Fzf window for commands
        #zinit light marlonrichert/zsh-autocomplete # Used for constant history box
        zinit light zsh-users/zsh-autosuggestions # Inline suggestion
        # zinit light jeffreytse/zsh-vi-mode # Vim bindings

        # Oh-My-Posh
        eval "$(${pkgs.oh-my-posh}/bin/oh-my-posh init zsh --config ~/.config/oh-my-posh/.omp-zsh.toml)"

        # === Keybindings ===

        # Navigation
        bindkey '^a' end-of-line # CTRL+A
        bindkey '^[[105;5u' beginning-of-line # CTRL+I
        bindkey '^b' backward-word # CTRL+B
        bindkey '^w' forward-word # CTRL+W
        bindkey '^h' backward-char # CTRL+H
        bindkey '^l' forward-char # CTRL+L

        # History
        bindkey '^k' history-search-backward # CTRL+K
        bindkey '^j' history-search-forward # CTRL+J
        #bindkey '^r' history-incremental-search-backward # CTRL+R

        # Modifying
        bindkey '^[^H' backward-kill-word # CTRL+ALT+Backspace
        bindkey '^f' autosuggest-accept # CTRL+F
        bindkey '^d' kill-line # CTRL+D
        bindkey '^u' undo # CTRL+U
        #bindkey '^y' redo # CTRL+Y

        # New line (not working yet)
        # bindkey '^\^^M' self-insert-unmeta # CTRL+ENTER

        bindkey '^[[108;6u' clear-screen # CTRL+SHIFT+L

        # Hotkey insertions
        bindkey -s '^Xgc' 'git commit -m ""\C-h' # Insert git commit template with cursor in quotes

        # === ===

        # Completion styling
        zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
        zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"
        zstyle ':completion:*' menu no
        zstyle ':completion:*' special-dirs false
        zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview 'lsd -A --color always --icon always $realpath'
        zstyle ':fzf-tab:complete:cd:*' fzf-preview 'lsd -A --color always --icon always $realpath'
        zstyle ':fzf-tab:*' fzf-flags --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
          --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
          --color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
          --color=selected-bg:#45475a \
          --multi \
          --bind=tab:accept
        #zstyle ':autocomplete:*' default-context history-incremental-search-backward
        #zstyle ':autocomplete:history-search:*' list-lines 8  # int
        #zstyle ':autocomplete:*' min-input 1

        # Load FZF Keybindings and Completions
        source ~/.local/share/zsh/fzf/key-bindings.zsh
        source ~/.local/share/zsh/fzf/completion.zsh

        # Replay deferred commands
        #zinit cdreplay -q

        # See hidden files
        setopt glob_dots

        # Shell integrations / Smart cd
        eval "$(zoxide init --cmd cd zsh)"

        # Load zsh-syntax-highlighting plugin at the end
        zinit light zsh-users/zsh-syntax-highlighting

      '';
    };
  };
}
