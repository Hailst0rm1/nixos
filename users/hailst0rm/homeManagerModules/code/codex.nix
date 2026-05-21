{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}: let
  perplexityKeyPath =
    if (config.sops.secrets ? "services/perplexity/api-key")
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
    if (config.sops.secrets ? "services/exa/api-key")
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
    if (config.sops.secrets ? "services/n8n/api-key")
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
in {
  options.code.codex.enable = lib.mkEnableOption "Enable Codex CLI";

  config = lib.mkIf config.code.codex.enable {
    programs.codex = {
      enable = true;
      package = pkgs-unstable.codex;

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
        model = "o3";
        approval_policy = "suggest";

        mcp_servers = {
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
          perplexity = {
            command = "${perplexityMcpWrapper}";
            args = [];
          };
          exa = {
            command = "${exaMcpWrapper}";
            args = [];
          };
          n8n = {
            command = "${n8nMcpWrapper}";
            args = [];
          };
        };
      };
    };

    # Ensure required dependencies are available
    home.packages = with pkgs; [
      uv # For Python MCP servers
      nodejs # For npm/npx MCP servers
      git # For git MCP server
    ];
  };
}
