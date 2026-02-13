{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.claude-mcp;

  # Build the MCP servers attrset based on enabled options
  mcpServers =
    {}
    // (optionalAttrs cfg.servers.nixos.enable {
      nixos = {
        command = "nix";
        args = ["run" "github:utensils/mcp-nixos" "--"];
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
