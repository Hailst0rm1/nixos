{
  config,
  lib,
  pkgs,
  ...
}: let
  claude-mcp-setup =
    /*
    shell
    */
    ''
          #!/usr/bin/env bash

          CONFIG_PATH="$HOME/.config/Claude/claude_desktop_config.json"

          # Prompt for Obsidian API key
          echo -n "Enter your Obsidian API key: "
          read -r OBSIDIAN_API_KEY

          # Create/override the config file
          mkdir -p "$(dirname "$CONFIG_PATH")"
          cat > "$CONFIG_PATH" <<EOF
      {
        "mcpServers": {
          "nixos": {
            "command": "nix",
            "args": ["run", "github:utensils/mcp-nixos", "--"]
          },
          "mcp-obsidian": {
            "command": "uvx",
            "args": [
            "mcp-obsidian"
            ],
            "env": {
              "OBSIDIAN_API_KEY": "$OBSIDIAN_API_KEY",
              "OBSIDIAN_HOST": "localhost",
              "OBSIDIAN_PORT": "27124"
            }
          },
          "google-calendar": {
            "command": "npx",
            "args": ["@cocal/google-calendar-mcp"],
            "env": {
              "GOOGLE_OAUTH_CREDENTIALS": "/home/hailst0rm/Downloads/calendar_creds.json"
            }
          }
        }
      }
      EOF
    '';
in {
  config = lib.mkIf config.applications.claude-desktop.enable {
    home.packages = with pkgs; [
      uv
      (writeShellScriptBin "claude-mcp-setup" claude-mcp-setup)
    ];
  };
}
