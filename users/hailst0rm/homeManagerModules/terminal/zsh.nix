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

        # Conventional commit + push
        gp() {
          local types=("feat" "fix" "chore" "docs" "style" "refactor" "perf" "test" "build" "ci" "revert")
          local type scope msg breaking prefix

          echo "Select commit type:"
          for i in {1..''${#types[@]}}; do
            echo "  $i) ''${types[$i]}"
          done
          printf "Type [1-''${#types[@]}]: "
          read -r choice
          if [[ -z "$choice" || "$choice" -lt 1 || "$choice" -gt ''${#types[@]} ]] 2>/dev/null; then
            echo "Invalid selection." && return 1
          fi
          type="''${types[$choice]}"

          printf "Scope (optional, enter to skip): "
          read -r scope

          printf "Breaking change? [y/N]: "
          read -r breaking

          printf "Message: "
          read -r msg
          if [[ -z "$msg" ]]; then
            echo "Commit message cannot be empty." && return 1
          fi

          # Build prefix
          prefix="$type"
          [[ -n "$scope" ]] && prefix="''${prefix}(''${scope})"
          [[ "$breaking" =~ ^[Yy]$ ]] && prefix="''${prefix}!"
          prefix="''${prefix}: ''${msg}"

          echo ""
          git status --short
          echo ""
          echo "Commit: $prefix"
          printf "Proceed? [Y/n]: "
          read -r confirm
          if [[ "$confirm" =~ ^[Nn]$ ]]; then
            echo "Aborted." && return 1
          fi

          git add -A && git commit -m "$prefix" && git push
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
