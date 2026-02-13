{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}: {
  options.code.claude-code.enable = lib.mkEnableOption "Enable Claude Code CLI";

  config = lib.mkIf config.code.claude-code.enable {
    programs.claude-code = {
      enable = true;
      package = pkgs-unstable.claude-code;

      # Coding preferences and context (CLAUDE.md equivalent)
      memory.text = ''
        # Coding Style & Preferences

        ## General
        - Use clear, descriptive variable and function names
        - Prefer explicit over implicit
        - Write idiomatic code for each language
        - Include error handling and edge cases
        - Add comments for complex logic, not obvious code

        ## NixOS Specific
        - Follow Nix best practices and RFC conventions
        - Use `lib.mkEnableOption` for boolean options
        - Use `lib.mkIf` for conditional configuration
        - Prefer `pkgs-unstable` for latest versions when needed
        - Structure modules with proper imports and options
        - Use `let...in` for complex attribute sets
        - Prefer functional programming patterns

        ## Security & Red Teaming
        - Follow OPSEC principles in all code
        - Never hardcode credentials or sensitive data
        - Use proper secret management (sops-nix, etc.)
        - Document security implications
        - Consider defensive coding practices
        - Think adversarially about code execution

        ## Code Organization
        - Keep functions small and focused (single responsibility)
        - Group related functionality
        - Use meaningful file and directory names
        - Maintain consistent formatting (nixfmt for Nix)

        ## Documentation
        - Write clear commit messages (conventional commits style)
        - Document non-obvious design decisions
        - Include usage examples for complex functions
        - Keep README files up to date

        ## Testing & Validation
        - Test configuration changes before deployment
        - Use `nixos-rebuild build` to verify before switch
        - Validate syntax with appropriate linters
        - Consider edge cases and failure modes
      '';

      # MCP (Model Context Protocol) servers
      mcpServers = {
        # NixOS-specific tooling
        nixos = {
          command = "nix";
          args = ["run" "github:utensils/mcp-nixos" "--"];
        };

        # Filesystem access (useful for workspace operations)
        filesystem = {
          command = "npx";
          args = ["-y" "@modelcontextprotocol/server-filesystem" "/home/hailst0rm/.nixos"];
        };

        # Git operations
        git = {
          command = "uvx";
          args = ["mcp-server-git" "--repository" "/home/hailst0rm/.nixos"];
        };

        # GitHub integration (if needed for PR reviews, issues, etc.)
        # github = {
        #   command = "npx";
        #   args = ["-y" "@modelcontextprotocol/server-github"];
        #   env = {
        #     GITHUB_PERSONAL_ACCESS_TOKEN = ""; # Set via environment or sops
        #   };
        # };
      };

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

      # Additional settings
      settings = {
        # Editor preferences (if claude-code supports this)
        editor = {
          tabSize = 2;
          insertSpaces = true;
        };

        # Terminal preferences
        terminal = {
          shell = "${pkgs.zsh}/bin/zsh";
        };
      };
    };

    # Ensure required dependencies are available
    home.packages = with pkgs; [
      uv # For Python MCP servers
      nodejs # For npm/npx MCP servers
      git # For git MCP server

      # Add companion package
      (pkgs.callPackage ../../../../pkgs/companion/package.nix {})

      # Claude Web launcher script
      (pkgs.writeShellScriptBin "claude-web" ''
        #!/usr/bin/env bash

        # Colours
        GREEN='\033[0;32m'
        BLUE='\033[0;34m'
        RESET='\033[0m'

        echo -e "''${BLUE}🚀 Starting The Vibe Companion...''${RESET}"

        # Start companion in background
        the-vibe-companion &>/dev/null &
        COMPANION_PID=$!

        # Wait a moment for it to start
        sleep 2

        # Open browser to localhost:3456
        echo -e "''${BLUE}🌐 Opening http://localhost:3456 in browser...''${RESET}"
        ${config.browser} http://localhost:3456 &>/dev/null &

        echo -e "''${GREEN}✓ Done!''${RESET}"
      '')
    ];
  };
}
