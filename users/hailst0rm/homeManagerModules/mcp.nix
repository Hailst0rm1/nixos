{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}:
with lib; let
  cfg = config.services.claude-mcp;

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

  # Wrapper that reads the Discord user token from sops and launches discord-self-mcp
  # Installs to a persistent directory on first run; explicitly adds 'debug' to fix
  # broken werift-rtp dependency (it uses debug but doesn't declare it)
  discordTokenPath =
    if (config.sops.secrets ? "services/discord/token")
    then config.sops.secrets."services/discord/token".path
    else "/run/secrets/services/discord/token";

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
    // (optionalAttrs cfg.servers.perplexity.enable {
      perplexity = {
        command = "${perplexityMcpWrapper}";
        args = [];
      };
    })
    // (optionalAttrs cfg.servers.exa.enable {
      exa = {
        command = "${exaMcpWrapper}";
        args = [];
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

      perplexity = {
        enable = mkEnableOption "Perplexity AI search MCP server";
      };

      exa = {
        enable = mkEnableOption "Exa web search MCP server";
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
