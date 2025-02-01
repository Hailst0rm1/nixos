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
      dotDir = ".config/zsh";

      history = {
        size = 10000;
        path = "${config.xdg.dataHome}/zsh/history";
      };

      oh-my-zsh = {
        enable = true;
        plugins = [ "git" "sudo" "aws" "command-not-found"];
      };

      envExtra = ''
        export TERMINAL="${config.terminal}"
        export TERM="${config.terminal}"
        export EDITOR="${config.editor}"
        export BROWSER="${config.browser}"
        export VIDEO="${config.video}"
        export IMAGE="${config.image}"
        export OPENER="xdg-open"
        #export LAUNCHER="cosmic-launcher"
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
        sudo="sudo ";
        ".."="cd ..";
        c="wl-copy";
        p="wl-paste";
        cl="clear";
        q = "exit";
        ":q" = "exit";
        nix-test="sudo nixos-rebuild test --flake $USER/.nixos#${config.hostname} --show-trace";
        nix-switch="sudo nixos-rebuild switch --flake $USER/.nixos#${config.hostname} --show-trace";
        nix-boot="sudo nixos-rebuild boot --flake $USER/.nixos#${config.hostname} --show-trace";

        # Modern commands
        ls="lsd";
        la="lsd -la";
        tree="lsd --tree -a";
        cat="bat -p";
        lgit="lazygit";
        ldocker="lazydocker";
        ljournal="lazyjournal";
        grep="batgrep";
        find="fd";
        du="dust";
        top="bottom";
        ps="procs";
        man="tldr --pager";
        sed="sd";
        diff="difft";
      };

      initExtra = ''
        ${pkgs-unstable.fastfetch}/bin/fastfetch

        nix-edit () {
          yazi ${config.nixosDir}
        }

       clean () {
          echo "Deleting all but 5 NixOS generations..."
          sudo ${pkgs.nh}/bin/nh clean all -k 5
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
      zinit light jeffreytse/zsh-vi-mode # Vim bindings

      # Oh-My-Posh
      eval "$(${pkgs.oh-my-posh}/bin/oh-my-posh init zsh --config ~/.config/oh-my-posh/.omp-zsh.toml)"

      # Keybindings
      bindkey '^K' history-search-backward
      bindkey '^J' history-search-forward
      bindkey '^F' autosuggest-accept
      #bindkey '^R' history-incremental-search-backward

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

      # Replay deferred commands
      #zinit cdreplay -q

      # See hidden files
      setopt glob_dots

      # Shell integrations / Smart cd
      eval "$(zoxide init --cmd cd zsh)"

      # Load zsh-syntax-highlighting plugin at the end
      zinit light zsh-users/zsh-syntax-highlighting

      # Load fzf (zsh-vim-function to set the correct binding)
      zvm_after_init_commands+=("source ~/.local/share/zsh/fzf/key-bindings.zsh" "source ~/.local/share/zsh/fzf/completion.zsh")
      #zvm_after_init_commands+=("source ~/.local/share/zsh/fzf/completion.zsh")

      '';

    };
  }; 
}
