{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  inputs,
  ...
}: let
  notebooklm-py = pkgs.callPackage ../../../../pkgs/notebooklm-py/package.nix {};
  codeburn = pkgs.callPackage ../../../../pkgs/codeburn/package.nix {};

  gsd-repo = pkgs.fetchFromGitHub {
    owner = "gsd-build";
    repo = "get-shit-done";
    rev = "v1.9.13";
    hash = "sha256-zm6Qr5Fk8AvlG7PcJOGBeed+PfbEPzE0swIljlgzyuY=";
  };

  # Wrapper that reads the Discord user token from sops and launches discord-self-mcp
  # Installs to a persistent directory on first run; explicitly adds 'debug' to fix
  # broken werift-rtp dependency (it uses debug but doesn't declare it)
  discordTokenPath =
    if config.importConfig.sops.enable
    then config.sops.secrets."services/discord/token".path
    else "/run/secrets/services/discord/token";

  perplexityKeyPath =
    if config.importConfig.sops.enable
    then config.sops.secrets."services/perplexity/api-key".path
    else "/run/secrets/services/perplexity/api-key";

  perplexityMcpWrapper = pkgs.writeShellScript "perplexity-mcp-wrapper" ''
    KEY_FILE="${perplexityKeyPath}"
    if [ -f "$KEY_FILE" ]; then
      export PERPLEXITY_API_KEY="$(cat "$KEY_FILE")"
    fi
    exec ${pkgs-unstable.perplexity-mcp}/bin/perplexity-mcp "$@"
  '';

  exaKeyPath =
    if config.importConfig.sops.enable
    then config.sops.secrets."services/exa/api-key".path
    else "/run/secrets/services/exa/api-key";

  exaMcpWrapper = pkgs.writeShellScript "exa-mcp-wrapper" ''
    KEY_FILE="${exaKeyPath}"
    if [ -f "$KEY_FILE" ]; then
      export EXA_API_KEY="$(cat "$KEY_FILE")"
    fi
    exec ${pkgs.nodejs}/bin/npx -y exa-mcp-server "$@"
  '';

  n8nApiKeyPath =
    if config.importConfig.sops.enable
    then config.sops.secrets."services/n8n/api-key".path
    else "/run/secrets/services/n8n/api-key";

  n8nMcpWrapper = pkgs.writeShellScript "n8n-mcp-wrapper" ''
    KEY_FILE="${n8nApiKeyPath}"
    if [ -f "$KEY_FILE" ]; then
      export N8N_API_KEY="$(cat "$KEY_FILE")"
    fi
    export N8N_API_URL="http://nix-server:5678"
    export WEBHOOK_SECURITY_MODE="permissive"
    export MCP_MODE="stdio"
    exec ${pkgs.nodejs}/bin/npx -y n8n-mcp "$@"
  '';

  githubPatPath =
    if config.importConfig.sops.enable
    then config.sops.secrets."services/github/pat".path
    else "/run/secrets/services/github/pat";

  githubMcpWrapper = pkgs.writeShellScript "github-mcp-wrapper" ''
    KEY_FILE="${githubPatPath}"
    if [ -f "$KEY_FILE" ]; then
      export GITHUB_PERSONAL_ACCESS_TOKEN="$(cat "$KEY_FILE")"
    fi
    exec ${pkgs.nodejs}/bin/npx -y @modelcontextprotocol/server-github "$@"
  '';

  discordMcpWrapper = pkgs.writeShellScript "discord-mcp-wrapper" ''
    TOKEN_FILE="${discordTokenPath}"
    if [ -f "$TOKEN_FILE" ]; then
      export DISCORD_TOKEN="$(cat "$TOKEN_FILE")"
    fi

    MCP_DIR="$HOME/.local/share/discord-self-mcp"
    if [ ! -f "$MCP_DIR/.installed" ]; then
      rm -rf "$MCP_DIR"
      mkdir -p "$MCP_DIR"
      cd "$MCP_DIR"
      ${pkgs.nodejs}/bin/npm install discord-self-mcp debug --save --loglevel=error >&2
      touch "$MCP_DIR/.installed"
    fi
    exec ${pkgs.nodejs}/bin/node "$MCP_DIR/node_modules/discord-self-mcp/dist/index.js" "$@"
  '';
in {
  options.code.claude-code = {
    enable = lib.mkEnableOption "Enable Claude Code CLI";
    n8n.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable n8n MCP server and skills for Claude Code.";
    };
  };

  config = lib.mkIf config.code.claude-code.enable {
    # Ensure direnv is active inside Claude's shell environment so
    # project-specific shell.nix / flake.nix envs are available to tool calls
    programs.zsh.envExtra = lib.mkAfter ''
      if command -v direnv >/dev/null; then
        if [[ -n "$CLAUDECODE" ]]; then
          eval "$(direnv hook zsh)"
          eval "$(DIRENV_LOG_FORMAT= direnv export zsh)"
          direnv status --json | ${pkgs.jq}/bin/jq -e ".state.foundRC.allowed==0" >/dev/null || direnv allow >/dev/null 2>&1
        fi
      fi
    '';

    programs.claude-code = {
      enable = true;
      package = pkgs-unstable.claude-code;

      # Skills (managed via skillsDir, see ./skills/)
      skillsDir = ./skills;

      # Global behavioral guidelines (Karpathy-inspired) → ~/.claude/CLAUDE.md
      memory.text = ''
        # CLAUDE.md

        Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

        **Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

        ## 1. Think Before Coding

        **Don't assume. Don't hide confusion. Surface tradeoffs.**

        Before implementing:
        - State your assumptions explicitly. If uncertain, ask.
        - If multiple interpretations exist, present them - don't pick silently.
        - If a simpler approach exists, say so. Push back when warranted.
        - If something is unclear, stop. Name what's confusing. Ask.

        ## 2. Simplicity First

        **Minimum code that solves the problem. Nothing speculative.**

        - No features beyond what was asked.
        - No abstractions for single-use code.
        - No "flexibility" or "configurability" that wasn't requested.
        - No error handling for impossible scenarios.
        - If you write 200 lines and it could be 50, rewrite it.

        Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

        ## 3. Surgical Changes

        **Touch only what you must. Clean up only your own mess.**

        When editing existing code:
        - Don't "improve" adjacent code, comments, or formatting.
        - Don't refactor things that aren't broken.
        - Match existing style, even if you'd do it differently.
        - If you notice unrelated dead code, mention it - don't delete it.

        When your changes create orphans:
        - Remove imports/variables/functions that YOUR changes made unused.
        - Don't remove pre-existing dead code unless asked.

        The test: Every changed line should trace directly to the user's request.

        ## 4. Goal-Driven Execution

        **Define success criteria. Loop until verified.**

        Transform tasks into verifiable goals:
        - "Add validation" → "Write tests for invalid inputs, then make them pass"
        - "Fix the bug" → "Write a test that reproduces it, then make it pass"
        - "Refactor X" → "Ensure tests pass before and after"

        For multi-step tasks, state a brief plan:
        ```
        1. [Step] → verify: [check]
        2. [Step] → verify: [check]
        3. [Step] → verify: [check]
        ```

        Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

        ---

        **These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.
      '';

      # General Nix ecosystem knowledge → ~/.claude/rules/nix-ecosystem.md
      rules.nix-ecosystem = ''
        # Nix Ecosystem

        General knowledge for working in any Nix-based environment.

        ## Package Discovery & Experimentation
        - Search for packages: `nix search nixpkgs <query>`
        - Try a package without installing: `nix shell nixpkgs#<package>` or `nix run nixpkgs#<package>`
        - Check package info: `nix eval nixpkgs#<package>.meta.description`
        - Use the MCP nixos tool to search packages, options, and documentation

        ## Development Environments with direnv
        Add a `shell.nix` or `default.nix` to the project directory:
        ```nix
        # save as shell.nix
        { pkgs ? import <nixpkgs> {}}:
        pkgs.mkShell {
          packages = [ pkgs.hello ];
        }
        ```
        Then enable direnv:
        ```shell
        echo "use nix" >> .envrc
        direnv allow
        ```
        For flake-based projects, use `use flake` instead of `use nix` in `.envrc`.

        ## Flakes
        - `nix flake show` — inspect flake outputs
        - `nix flake check` — validate a flake
        - `nix flake update` — update all inputs
        - `nix flake lock --update-input <input>` — update a single input

        ## Secrets Management
        - Use sops-nix for managing secrets in NixOS configurations
        - Never hardcode credentials or sensitive data
        - Secret files are encrypted at rest and decrypted at activation time
        - Access secrets via `config.sops.secrets.<name>.path`

        ## Debugging
        - `nix repl` — interactive Nix evaluator; load a flake with `:lf .`
        - `nix eval` — evaluate an expression without building
        - `nix build --print-build-logs` — see full build output
        - `nixos-rebuild build` — verify a NixOS config builds without switching

        ## Security
        - Follow OPSEC principles in all code
        - Think adversarially about code execution
        - Consider defensive coding practices
        - Document security implications of changes
      '';

      # Custom commands for common workflows
      # commands = {
      #   # NixOS rebuild shortcut
      #   rebuild = {
      #     description = "Rebuild NixOS configuration";
      #     command = "sudo nixos-rebuild switch --flake /home/hailst0rm/.nixos";
      #   };

      #   # Home Manager rebuild
      #   home-rebuild = {
      #     description = "Rebuild Home Manager configuration";
      #     command = "home-manager switch --flake /home/hailst0rm/.nixos";
      #   };

      #   # Format Nix files
      #   fmt-nix = {
      #     description = "Format Nix files in current directory";
      #     command = "nixfmt **/*.nix";
      #   };

      #   # Check flake
      #   # check-flake = {
      #   #   description = "Check flake for errors";
      #   #   command = "cd /home/hailst0rm/.nixos && nix flake check";
      #   # };
      # };

      # MCP (Model Context Protocol) servers
      mcpServers =
        {
          nixos = {
            command = "nix";
            args = ["run" "github:utensils/mcp-nixos" "--"];
          };
          filesystem = {
            command = "npx";
            args = ["-y" "@modelcontextprotocol/server-filesystem" "/home/hailst0rm/.nixos"];
          };
          git = {
            command = "uvx";
            args = ["mcp-server-git" "--repository" "/home/hailst0rm/.nixos"];
          };
          discord = {
            command = "${discordMcpWrapper}";
            args = [];
          };
          perplexity = {
            command = "${perplexityMcpWrapper}";
            args = [];
          };
          exa = {
            command = "${exaMcpWrapper}";
            args = [];
          };
          github = {
            command = "${githubMcpWrapper}";
            args = [];
          };
        }
        // lib.optionalAttrs config.code.claude-code.n8n.enable {
          n8n = {
            command = "${n8nMcpWrapper}";
            args = [];
          };
        };

      # Additional settings
      settings = {
        showThinkingSummaries = true;
        cleanupPeriodDays = 14;
        includeCoAuthoredBy = false;

        permissions = {
          allow = [
            "Read"
            "Glob"
            "Grep"
            "LS"
            "Edit"
            "MultiEdit"
            "Write"
            "Bash(git status)"
            "Bash(git diff *)"
            "Bash(git log *)"
            "Bash(git add *)"
            "Bash(git commit *)"
            "Bash(git checkout *)"
            "Bash(git branch *)"
            "Bash(nix *)"
            "Bash(nixfmt *)"
            "Bash(nixos-rebuild build *)"
          ];
          deny = [
            "Bash(sops:*)"
            "Bash(age:*)"
            "Read(/run/secrets/**)"
            "Read(/run/secrets.d/**)"
            "Read(/home/hailst0rm/.config/sops/**)"
            "Read(/home/hailst0rm/.config/sops-nix/**)"
          ];
        };

        env = {
          CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR = "1";
        };

        # Plugins
        enabledPlugins =
          {
            "skill-creator@claude-plugins-official" = true;
            "superpowers@claude-plugins-official" = true;
            "frontend-design@claude-plugins-official" = true;
            "obsidian@obsidian-skills" = true;
            "context-mode@context-mode" = true;
          }
          // lib.optionalAttrs config.code.claude-code.n8n.enable {
            "n8n-skills@n8n-skills" = true;
          };

        extraKnownMarketplaces =
          {
            claude-plugins-official = {
              source = {
                source = "github";
                repo = "anthropics/claude-plugins-official";
              };
            };
            obsidian-skills = {
              source = {
                source = "github";
                repo = "kepano/obsidian-skills";
              };
            };
            context-mode = {
              source = {
                source = "github";
                repo = "mksglu/context-mode";
              };
            };
          }
          // lib.optionalAttrs config.code.claude-code.n8n.enable {
            n8n-skills = {
              source = {
                source = "github";
                repo = "czlonkowski/n8n-skills";
              };
            };
          };

        # Editor preferences (if claude-code supports this)
        editor = {
          tabSize = 4;
          insertSpaces = true;
        };

        # Terminal preferences
        terminal = {
          shell = "${pkgs.zsh}/bin/zsh";
        };
      };
    };

    # GSD (Get Shit Done) commands and agents
    home.file.".claude/commands/gsd".source = "${gsd-repo}/commands/gsd";
    home.file.".claude/agents" = {
      source = "${gsd-repo}/agents";
      recursive = true;
    };

    # VS Code settings for Claude Code extension (only when VS Code is enabled)
    programs.vscode.profiles.default.userSettings = lib.mkIf config.code.vscode.enable {
      "claudeCode.allowDangerouslySkipPermissions" = true;
      "claudeCode.enableNewConversationShortcut" = true;
      "claudeCode.claudeProcessWrapper" = "${config.programs.claude-code.finalPackage}/bin/claude";
    };

    # Ensure required dependencies are available
    home.packages = with pkgs; [
      uv # For Python MCP servers
      nodejs # For npm/npx MCP servers
      git # For git MCP server

      # NotebookLM automation CLI
      notebooklm-py

      # AI coding token usage tracker
      codeburn
    ];
  };
}
