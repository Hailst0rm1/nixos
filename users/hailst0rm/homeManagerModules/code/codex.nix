{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  mkSecretEnvWrapper,
  inputs,
  ...
}: let
  perplexityMcpWrapper = mkSecretEnvWrapper {
    name = "perplexity-mcp-wrapper";
    env.PERPLEXITY_API_KEY = "services/perplexity/api-key";
    command = "${pkgs-unstable.perplexity-mcp}/bin/perplexity-mcp";
  };

  exaMcpWrapper = mkSecretEnvWrapper {
    name = "exa-mcp-wrapper";
    env.EXA_API_KEY = "services/exa/api-key";
    command = "${pkgs.nodejs}/bin/npx -y exa-mcp-server";
  };

  n8nMcpWrapper = mkSecretEnvWrapper {
    name = "n8n-mcp-wrapper";
    env.N8N_API_KEY = "services/n8n/api-key";
    staticEnv = {
      N8N_API_URL = "http://nix-server:5678";
      WEBHOOK_SECURITY_MODE = "permissive";
      MCP_MODE = "stdio";
    };
    command = "${pkgs.nodejs}/bin/npx -y n8n-mcp";
  };

  # Home Manager normally links this into ~/.codex from /nix/store, but Codex
  # writes trust decisions and other interactive settings back to config.toml.
  # Install a real copy so those writes work; the next activation restores the
  # declared defaults, matching the mutable settings setup used for Claude.
  codexConfigFile =
    (pkgs.formats.toml {}).generate "codex-config.toml"
    config.programs.codex.settings;
  codexConfigInstall = pkgs.writeShellScript "codex-config-install" ''
    dst="$HOME/.codex/config.toml"
    ${pkgs.coreutils}/bin/mkdir -p "$HOME/.codex"
    ${pkgs.coreutils}/bin/rm -f "$dst"
    ${pkgs.coreutils}/bin/install -m 0644 ${codexConfigFile} "$dst"
  '';
in {
  options.code.codex = {
    enable = lib.mkEnableOption "Enable Codex CLI";
    perplexity.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the Perplexity web search MCP server for Codex.";
    };
  };

  config = lib.mkIf config.code.codex.enable {
    programs.codex = {
      enable = true;
      package = inputs.codex-cli-nix.packages.x86_64-linux.default;

      # Global context → ~/.codex/AGENTS.md (equivalent to Claude's CLAUDE.md)
      custom-instructions = ''
        # AGENTS.md

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

      # NEEDS FLAKE UPDATE
      # Rules (equivalent to Claude's rules)
      # rules.nix-ecosystem = ''
      #   # Nix Ecosystem

      #   General knowledge for working in any Nix-based environment.

      #   ## Package Discovery & Experimentation
      #   - Search for packages: `nix search nixpkgs <query>`
      #   - Try a package without installing: `nix shell nixpkgs#<package>` or `nix run nixpkgs#<package>`
      #   - Check package info: `nix eval nixpkgs#<package>.meta.description`

      #   ## Development Environments with direnv
      #   Add a `shell.nix` or `default.nix` to the project directory:
      #   ```nix
      #   # save as shell.nix
      #   { pkgs ? import <nixpkgs> {}}:
      #   pkgs.mkShell {
      #     packages = [ pkgs.hello ];
      #   }
      #   ```
      #   Then enable direnv:
      #   ```shell
      #   echo "use nix" >> .envrc
      #   direnv allow
      #   ```
      #   For flake-based projects, use `use flake` instead of `use nix` in `.envrc`.

      #   ## Flakes
      #   - `nix flake show` — inspect flake outputs
      #   - `nix flake check` — validate a flake
      #   - `nix flake update` — update all inputs
      #   - `nix flake lock --update-input <input>` — update a single input

      #   ## Secrets Management
      #   - Use sops-nix for managing secrets in NixOS configurations
      #   - Never hardcode credentials or sensitive data
      #   - Secret files are encrypted at rest and decrypted at activation time
      #   - Access secrets via `config.sops.secrets.<name>.path`

      #   ## Debugging
      #   - `nix repl` — interactive Nix evaluator; load a flake with `:lf .`
      #   - `nix eval` — evaluate an expression without building
      #   - `nix build --print-build-logs` — see full build output
      #   - `nixos-rebuild build` — verify a NixOS config builds without switching

      #   ## Security
      #   - Follow OPSEC principles in all code
      #   - Think adversarially about code execution
      #   - Consider defensive coding practices
      #   - Document security implications of changes
      # '';

      # Settings → ~/.codex/config.toml
      settings = {
        # Equivalent to Claude Code's bypassPermissions mode. Codex can run
        # commands directly on the host without sandboxing or approval prompts.
        approval_policy = "never";
        sandbox_mode = "danger-full-access";

        # Native approximation of the Claude status line, in the same order:
        # version, model, project/worktree, branch + diff, context, rate limits.
        # Codex has no native hostname or per-session USD-cost status items.
        tui.status_line = [
          "codex-version"
          "model-with-reasoning"
          "project-name"
          "current-dir"
          "git-branch"
          "branch-changes"
          "context-used"
          "five-hour-limit"
          "weekly-limit"
        ];

        # Built-in image_gen tool (gpt-image, backed by the ChatGPT subscription).
        # Serialized to ~/.codex/config.toml [features]; reaches interactive Codex,
        # the /imagegen command, and the Claude Code codex plugin's `codex exec`.
        features.image_generation = true;

        mcp_servers =
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
            exa = {
              command = "${exaMcpWrapper}";
              args = [];
            };
            n8n = {
              command = "${n8nMcpWrapper}";
              args = [];
            };
          }
          // lib.optionalAttrs config.code.codex.perplexity.enable {
            perplexity = {
              command = "${perplexityMcpWrapper}";
              args = [];
            };
          };
      };
    };

    home.file.".codex/config.toml".enable = false;

    # linkGeneration first removes the previous generation's symlink, then this
    # activation step replaces it with the writable copy Codex expects.
    home.activation.codexConfig = lib.hm.dag.entryAfter ["linkGeneration"] ''
      run ${codexConfigInstall}
    '';

    # Ensure required dependencies are available
    home.packages = with pkgs; [
      uv # For Python MCP servers
      nodejs # For npm/npx MCP servers
      git # For git MCP server
    ];

    # /imagegen Claude Code slash command: generate images via Codex's built-in
    # image_gen tool (ChatGPT subscription, no metered API key).
    home.file.".claude/commands/imagegen.md".text = ''
      ---
      description: Generate an image with Codex's image_gen (ChatGPT subscription)
      allowed-tools: Bash(codex exec:*)
      ---
      Generate an image using Codex's built-in `image_gen` tool, which is backed by the
      ChatGPT subscription (no metered API key).

      Run (substitute the user's request for the prompt; pick a sensible PNG output path
      in the current directory if the user didn't give one):

      ```bash
      codex exec --skip-git-repo-check --sandbox workspace-write \
        --enable image_generation \
        "Use the image_gen tool to create an image of: $ARGUMENTS. \
         Save the result as a PNG in the current working directory and \
         print the exact saved filename on the last line."
      ```

      Then report the saved file path to the user.
    '';
  };
}
