{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  mkSecretEnvWrapper,
  ...
}:
with lib; let
  cfg = config.services.claude-mcp;

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

  # Build the MCP servers attrset based on enabled options
  mcpServers =
    {}
    // (optionalAttrs cfg.servers.nixos.enable {
      nixos = {
        command = "nix";
        args = ["run" "github:utensils/mcp-nixos" "--"];
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
