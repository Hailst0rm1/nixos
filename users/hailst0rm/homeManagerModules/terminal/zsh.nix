{
  pkgs,
  pkgs-unstable,
  config,
  lib,
  ...
}: let
  # ── Shared config: used by both user (Home Manager) and root (system-level) ──
  sharedAliases = ''
    alias sudo="sudo "
    alias ..="cd .."
    alias cl="clear"
    alias q="exit"
    alias s="source"
    alias ":q"="exit"
    alias ls="${pkgs-unstable.lsd}/bin/lsd"
    alias la="${pkgs-unstable.lsd}/bin/lsd -lah"
    alias tree="${pkgs-unstable.lsd}/bin/lsd --tree -a"
    alias cat="${pkgs-unstable.bat}/bin/bat -pp"
    alias lat="${pkgs-unstable.bat}/bin/bat -p"
    alias less="${pkgs-unstable.bat}/bin/bat"
    alias lgit="${pkgs.lazygit}/bin/lazygit"
    alias du="${pkgs-unstable.dust}/bin/dust"
    alias diff="${pkgs-unstable.difftastic}/bin/difft"
  '';

  sharedKeybindings = ''
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

    # Modifying
    bindkey '^[^H' backward-kill-word # CTRL+ALT+Backspace
    bindkey '^f' autosuggest-accept # CTRL+F
    bindkey '^d' kill-line # CTRL+D
    bindkey '^u' undo # CTRL+U

    bindkey '^[[108;6u' clear-screen # CTRL+SHIFT+L

    # Hotkey insertions
    bindkey -s '^Xgc' 'git commit -m ""\C-h'
  '';

  sharedCompletionStyle = ''
    zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
    zstyle ':completion:*' menu no
    zstyle ':completion:*' special-dirs false
    zstyle ':fzf-tab:complete:__zoxide_z:*' fzf-preview '${pkgs-unstable.lsd}/bin/lsd -A --color always --icon always $realpath'
    zstyle ':fzf-tab:complete:cd:*' fzf-preview '${pkgs-unstable.lsd}/bin/lsd -A --color always --icon always $realpath'
    zstyle ':fzf-tab:*' fzf-flags --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
      --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
      --color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
      --color=selected-bg:#45475a \
      --multi \
      --bind=tab:accept
  '';

  sharedFzfOpts = ''
    export FZF_DEFAULT_OPTS=" \
      --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
      --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
      --color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
      --color=selected-bg:#45475a \
      --multi"
  '';

  sharedPluginInit = ''
    # Source/Load Zinit
    export ZINIT_HOME="${pkgs.zinit}/share/zinit"
    source "''${ZINIT_HOME}/zinit.zsh" 2>/dev/null

    # Plugins
    zinit light zsh-users/zsh-completions
    zinit light Aloxaf/fzf-tab
    zinit light zsh-users/zsh-autosuggestions
  '';

  sharedPostInit = ''
    # FZF keybindings and completions
    source "${pkgs.fzf}/share/fzf/key-bindings.zsh" 2>/dev/null
    source "${pkgs.fzf}/share/fzf/completion.zsh" 2>/dev/null

    # See hidden files
    setopt glob_dots

    # Smart cd
    eval "$(${pkgs-unstable.zoxide}/bin/zoxide init --cmd cd zsh)"

    # Syntax highlighting (must be last)
    zinit light zsh-users/zsh-syntax-highlighting
  '';

  # ── Root init script: written to a file that utils.nix sources at runtime ──
  rootInitScript = pkgs.writeText "root-zsh-init.sh" ''
    ${sharedPluginInit}

    # Oh-My-Posh (root theme with skull)
    eval "$(${pkgs.oh-my-posh}/bin/oh-my-posh init zsh --config /home/hailst0rm/.config/oh-my-posh/.omp-zsh-root.toml)"

    ${sharedAliases}
    ${sharedKeybindings}
    ${sharedCompletionStyle}
    ${sharedFzfOpts}
    ${sharedPostInit}
  '';
in {
  # Expose the root init script path for utils.nix to reference
  options.zshRootInitScript = lib.mkOption {
    type = lib.types.path;
    default = rootInitScript;
    internal = true;
  };

  config = lib.mkIf (config.shell == "zsh") {
    home.file = {
      ".local/share/zsh/zinit".source = "${pkgs.zinit}/share/zinit";
      ".local/share/zsh/zinit".recursive = true;
      ".local/share/zsh/fzf".source = "${pkgs.fzf}/share/fzf";

      # Root init script — deployed to a known path for system-level sourcing
      ".config/zsh/root-init.zsh".source = rootInitScript;
    };

    programs.zsh = {
      enable = true;
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
        export GIT_EXTERNAL_DIFF="difft"
        export ZINIT_HOME="$HOME/.local/share/zsh/zinit"
        ${sharedFzfOpts}
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
        claude = "claude --allow-dangerously-skip-permissions";

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
          if [[ "$1" == "--no-auth" ]]; then
            echo -e '\033[0;36m📡 Fetching remote changes (HTTPS, no-auth)...\033[0m'
            git -C ~/.nixos fetch https://github.com/hailst0rm1/nixos.git master:refs/remotes/origin/master --quiet 2>/dev/null || {
              echo -e '\033[0;31m❌ Fetch failed. Check your internet connection.\033[0m'
              return 1
            }
            local LOCAL=$(git -C ~/.nixos rev-parse HEAD)
            local REMOTE=$(git -C ~/.nixos rev-parse origin/master 2>/dev/null)
            if [ "$LOCAL" = "$REMOTE" ]; then
              echo -e '\033[0;32m✅ Already up to date.\033[0m'
            else
              local BEHIND=$(git -C ~/.nixos rev-list HEAD..origin/master --count 2>/dev/null || echo "0")
              echo -e "\033[0;33m⬇️  Rebasing $BEHIND commit(s) from remote...\033[0m"
              git -C ~/.nixos rebase origin/master || {
                # Auto-resolve known per-host files by keeping local version
                local conflict_files=$(git -C ~/.nixos diff --name-only --diff-filter=U 2>/dev/null)
                local auto_resolved=true
                for f in $conflict_files; do
                  case "$f" in
                    pkgs/companion/package.nix)
                      echo -e "\033[0;33m⚠️  Auto-resolving $f (keeping local version)\033[0m"
                      git -C ~/.nixos checkout --ours "$f"
                      git -C ~/.nixos add "$f"
                      ;;
                    *)
                      auto_resolved=false
                      ;;
                  esac
                done
                if [ "$auto_resolved" = true ] && [ -n "$conflict_files" ]; then
                  git -C ~/.nixos rebase --continue || {
                    echo -e '\033[0;31m❌ Rebase failed. Resolve conflicts in ~/.nixos then run: git rebase --continue\033[0m'
                    return 1
                  }
                elif [ "$auto_resolved" = false ]; then
                  echo -e '\033[0;31m❌ Rebase failed. Resolve conflicts in ~/.nixos then run: git rebase --continue\033[0m'
                  return 1
                fi
              }
              echo -e '\033[0;32m✅ Rebased successfully.\033[0m'
            fi
          else
            git -C ~/.nixos pull "$@"
          fi
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

        # Add in zsh plugins
        zinit light zsh-users/zsh-completions # Command flag completions
        zinit light Aloxaf/fzf-tab # Fzf window for commands
        zinit light zsh-users/zsh-autosuggestions # Inline suggestion

        # Oh-My-Posh
        eval "$(${pkgs.oh-my-posh}/bin/oh-my-posh init zsh --config ~/.config/oh-my-posh/.omp-zsh.toml)"

        ${sharedKeybindings}

        # Completion styling
        zstyle ':completion:*' list-colors "''${(s.:.)LS_COLORS}"
        ${sharedCompletionStyle}

        # Load FZF Keybindings and Completions
        source ~/.local/share/zsh/fzf/key-bindings.zsh
        source ~/.local/share/zsh/fzf/completion.zsh

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
