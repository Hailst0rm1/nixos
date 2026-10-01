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

  context7McpWrapper = mkSecretEnvWrapper {
    name = "context7-mcp-wrapper";
    env.CONTEXT7_API_KEY = "services/context7/api-key";
    command = "${pkgs.nodejs}/bin/npx -y @upstash/context7-mcp";
  };

  codegraphMcpWrapper = mkSecretEnvWrapper {
    name = "codegraph-mcp-wrapper";
    staticEnv.CODEGRAPH_TELEMETRY = "0";
    command = "${pkgs.nodejs}/bin/npx -y @colbymchenry/codegraph serve --mcp";
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
    shareClaudeSkills.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Expose Claude Code's skills and compatible enabled plugins to Codex.";
    };
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

      # Global context → ~/.codex/AGENTS.md. Claude's CLAUDE.md is the one
      # source, so the two cannot drift. Codex `rules` are command-approval
      # `.rules` files, not instructions, so the nix-ecosystem rule rides along
      # here instead.
      context =
        builtins.replaceStrings ["# CLAUDE.md"] ["# AGENTS.md"] config.programs.claude-code.context
        + "\n"
        + config.programs.claude-code.rules.nix-ecosystem;

      # Settings → ~/.codex/config.toml
      settings = {
        # Equivalent to Claude Code's bypassPermissions mode. Codex can run
        # commands directly on the host without sandboxing or approval prompts.
        approval_policy = "never";
        sandbox_mode = "danger-full-access";

        # Native approximation of the Claude status line, in the same order:
        # version, model, project, branch + diff, context, rate limits.
        # Codex has no native hostname or per-session USD-cost status items.
        tui.status_line = [
          "codex-version"
          "model-with-reasoning"
          "project-name"
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
          }
          # Same switches as Claude Code, so one toggle covers both agents.
          // lib.optionalAttrs config.code.claude-code.context7.enable {
            context7 = {
              command = "${context7McpWrapper}";
              args = [];
            };
          }
          // lib.optionalAttrs config.code.claude-code.codegraph.enable {
            codegraph = {
              command = "${codegraphMcpWrapper}";
              args = [];
            };
          }
          // lib.optionalAttrs config.code.claude-code.n8n.enable {
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

    # Keep Codex's own .system skills intact while exposing the skills Claude
    # currently has. Plugins with a native Codex manifest are installed whole
    # so their hooks and commands survive; skill-only plugins fall back to links.
    home.activation.codexClaudeSkills = lib.mkIf config.code.codex.shareClaudeSkills.enable (
      lib.hm.dag.entryAfter ["claudeSettings" "codexConfig"] ''
        codex_skills="$HOME/.codex/skills"
        skill_manifest="$HOME/.codex/.claude-shared-skills"
        plugin_manifest="$HOME/.codex/.claude-shared-plugins"
        next_skill_manifest=$(${pkgs.coreutils}/bin/mktemp)
        next_plugin_manifest=$(${pkgs.coreutils}/bin/mktemp)
        # Home Manager activation has a deliberately minimal PATH. Codex uses
        # git internally when materialising Git-backed local plugin sources.
        export PATH="${pkgs.git}/bin:$PATH"
        run ${pkgs.coreutils}/bin/mkdir -p "$codex_skills"

        share_skill() {
          source="$1"
          name=$(${pkgs.coreutils}/bin/basename "$(${pkgs.coreutils}/bin/dirname "$source")")
          destination="$codex_skills/$name"

          # Leave an existing managed link untouched. Recreating every link on
          # each activation makes a running Codex watcher register duplicates.
          if [ -L "$destination" ]; then
            target=$(${pkgs.coreutils}/bin/readlink "$destination")
            case "$target" in
              "$HOME/.claude/"*)
                ${pkgs.coreutils}/bin/printf '%s\n' "$destination" >> "$next_skill_manifest"
                return
                ;;
            esac
          fi

          # Never replace a Codex-native or manually installed skill.
          if [ ! -e "$destination" ] && [ ! -L "$destination" ]; then
            run ${pkgs.coreutils}/bin/ln -s "$(${pkgs.coreutils}/bin/dirname "$source")" "$destination"
            ${pkgs.coreutils}/bin/printf '%s\n' "$destination" >> "$next_skill_manifest"
          fi
        }

        if [ -d "$HOME/.claude/skills" ]; then
          while IFS= read -r skill; do
            share_skill "$skill"
          done < <(${pkgs.findutils}/bin/find -L "$HOME/.claude/skills" -mindepth 2 -maxdepth 2 -name SKILL.md -type f | ${pkgs.coreutils}/bin/sort)
        fi

        settings="$HOME/.claude/settings.json"
        if [ -f "$settings" ]; then
          while IFS= read -r plugin; do
            marketplace="''${plugin#*@}"
            # Pinned marketplaces (claude-code.nix pluginMarketplaces) are store
            # trees linked here; the unpinned ones are Claude's own git clones.
            plugin_root="$HOME/.claude/marketplaces/$marketplace"
            [ -d "$plugin_root" ] || plugin_root="$HOME/.claude/plugins/marketplaces/$marketplace"
            if [ -d "$plugin_root" ]; then
              if [ -f "$plugin_root/.codex-plugin/plugin.json" ]; then
                plugin_name="''${plugin%@*}"
                # `codex plugin marketplace add` re-clones the plugin's git
                # remote, so it fails whenever the network is down — and at boot
                # Home Manager activates before DNS is up. Unguarded, that
                # failure aborts the entire activation run under `set -e`:
                # everything after this point is skipped, including
                # reloadSystemd, so user services deleted from the config keep
                # running from the previous generation (this stranded the v1
                # quickshell bar and OSD alongside serpantinum). Skip the plugin
                # instead and carry its previous registration forward so the
                # prune below does not uninstall it; the next activation with a
                # network reconciles it.
                codex_marketplace=$(${config.programs.codex.package}/bin/codex plugin marketplace add "$plugin_root" --json | ${pkgs.jq}/bin/jq -r .marketplaceName) || true
                if [ -n "$codex_marketplace" ] && [ "$codex_marketplace" != "null" ] \
                  && run ${config.programs.codex.package}/bin/codex plugin add "$plugin_name@$codex_marketplace" --json >/dev/null; then
                  ${pkgs.coreutils}/bin/printf '%s\n' "$plugin_name@$codex_marketplace" >> "$next_plugin_manifest"
                elif [ -f "$plugin_manifest" ]; then
                  ${pkgs.gnugrep}/bin/grep "^$plugin_name@" "$plugin_manifest" >> "$next_plugin_manifest" || true
                fi
              else
                while IFS= read -r skill; do
                  share_skill "$skill"
                done < <(${pkgs.findutils}/bin/find -L "$plugin_root/skills" -mindepth 2 -name SKILL.md -type f 2>/dev/null | ${pkgs.coreutils}/bin/sort)
              fi
            fi
          done < <(${pkgs.jq}/bin/jq -r '.enabledPlugins // {} | to_entries[] | select(.value == true) | .key' "$settings")
        fi

        if [ -f "$skill_manifest" ]; then
          while IFS= read -r destination; do
            if ! ${pkgs.gnugrep}/bin/grep -Fxq "$destination" "$next_skill_manifest" && [ -L "$destination" ]; then
              target=$(${pkgs.coreutils}/bin/readlink "$destination")
              case "$target" in
                "$HOME/.claude/"*) run ${pkgs.coreutils}/bin/rm -f "$destination" ;;
              esac
            fi
          done < "$skill_manifest"
        fi

        if [ -f "$plugin_manifest" ]; then
          while IFS= read -r plugin; do
            if ! ${pkgs.gnugrep}/bin/grep -Fxq "$plugin" "$next_plugin_manifest"; then
              ${config.programs.codex.package}/bin/codex plugin remove "$plugin" --json >/dev/null 2>&1 || true
            fi
          done < "$plugin_manifest"
        fi

        run ${pkgs.coreutils}/bin/mv "$next_skill_manifest" "$skill_manifest"
        run ${pkgs.coreutils}/bin/mv "$next_plugin_manifest" "$plugin_manifest"
      ''
    );

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
