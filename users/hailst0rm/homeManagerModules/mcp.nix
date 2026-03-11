{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.claude-mcp;

  # Wrapper that reads the Discord user token from sops and launches discord-self-mcp
  # Installs to a persistent directory on first run; explicitly adds 'debug' to fix
  # broken werift-rtp dependency (it uses debug but doesn't declare it)
  discordMcpWrapper = pkgs.writeShellScript "discord-mcp-wrapper" ''
    TOKEN_FILE="${config.sops.secrets."services/discord/token".path}"
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

  # Build the MCP servers attrset based on enabled options
  mcpServers =
    {}
    // (optionalAttrs cfg.servers.nixos.enable {
      nixos = {
        command = "nix";
        args = ["run" "github:utensils/mcp-nixos" "--"];
      };
    })
    // (optionalAttrs cfg.servers.discord.enable {
      discord = {
        command = "${discordMcpWrapper}";
        args = [];
      };
    })
    // (optionalAttrs cfg.servers.obsidian.enable {
      mcp-obsidian = {
        command = "uvx";
        args = ["mcp-obsidian"];
        env = {
          OBSIDIAN_API_KEY = cfg.servers.obsidian.apiKey;
          OBSIDIAN_HOST = cfg.servers.obsidian.host;
          OBSIDIAN_PORT = toString cfg.servers.obsidian.port;
        };
      };
    });

  configJson = builtins.toJSON {inherit mcpServers;};
in {
  options.services.claude-mcp = {
    enable = mkEnableOption "Claude Desktop MCP server configuration";

    servers = {
      nixos = {
        enable = mkEnableOption "NixOS MCP server";
      };

      discord = {
        enable = mkEnableOption "Discord MCP server (read servers, channels, messages)";
      };

      obsidian = {
        enable = mkEnableOption "Obsidian MCP server";

        apiKey = mkOption {
          type = types.str;
          default = "";
          description = "Obsidian Local REST API key. Set this to the API key from the Obsidian Local REST API plugin.";
        };

        host = mkOption {
          type = types.str;
          default = "localhost";
          description = "Obsidian REST API host.";
        };

        port = mkOption {
          type = types.port;
          default = 27124;
          description = "Obsidian REST API port.";
        };
      };
    };
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      uv
    ];

    # Declaratively manage the Claude Desktop MCP config
    home.file.".config/Claude/claude_desktop_config.json" = {
      text = configJson;
    };
  };
}
