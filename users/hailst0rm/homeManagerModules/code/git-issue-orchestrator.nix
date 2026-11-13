{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.code.git-issue-orchestrator;
  # The agents' HOME (docs/linux.md). The engine makes it, and resets it to 0700, at start.
  agentHome = ".local/share/git-issue-orchestrator/agent-home";
  gitCfg = config.programs.git;
in {
  options.code.git-issue-orchestrator = {
    enable = lib.mkEnableOption "the Dfirmed Git-Issue Orchestrator (engine, desktop app and MCP server)";
    # The desktop app is the usual way to run it: it starts and stops the engine itself (ADR 0052).
    desktop.enable = lib.mkOption {
      type = lib.types.bool;
      default = cfg.enable;
      description = "Add the orchestrator's desktop app to the launcher.";
    };
    # Registration lives in claude-code.nix, codex.nix and mcp.nix beside the other servers.
    mcp.enable = lib.mkOption {
      type = lib.types.bool;
      default = cfg.enable;
      description = "Register orchestrator-mcp with Claude Code, Codex and Claude Desktop.";
    };
  };

  config = lib.mkIf cfg.enable {
    # bwrap, socat and git: the engine runs them, and the box finds them again in this profile
    # for the CLIs' own sandboxes (docs/linux.md). xvfb-run: agents' screenshots (ADR 0042).
    home.packages = with pkgs; [git-issue-orchestrator bubblewrap socat git xvfb-run];

    # shortcut: works around two engine gaps reported on upstream #78; drop once the engine
    # makes these writable and gives agents an identity itself.
    home.file = {
      # Agents commit as you: your default identity plus the per-remote includes from git.nix.
      # In .config/git, not ~/.gitconfig: the box mounts both read-only, and bwrap can't mount
      # onto the symlink home.file makes; .config/git is a real folder holding it.
      "${agentHome}/.config/git/config" = lib.mkIf gitCfg.enable {
        # [user] first: git lets the later section win, so the includes must come after it.
        text =
          lib.generators.toGitINI {inherit (gitCfg.settings) user;}
          + lib.generators.toGitINI {
            includeIf =
              lib.listToAttrs (map (i: lib.nameValuePair i.condition {path = "${i.path}";})
                (lib.filter (i: i.condition != null) gitCfg.includes));
          };
      };
      # Claude Code's own sandbox only writes what the engine lists (ADR 0055), so nix develop,
      # npm and cargo fail on their caches in the agent home.
      "${agentHome}/.claude/settings.json".text = builtins.toJSON {
        sandbox.filesystem.allowWrite = map (d: "${config.home.homeDirectory}/${agentHome}/${d}") [".cache/nix" ".npm" ".cargo"];
      };
    };

    xdg.desktopEntries.git-issue-orchestrator = lib.mkIf cfg.desktop.enable {
      name = "Orchestrator";
      comment = "Run coding agents on GitHub issues";
      exec = "orchestrator-desktop";
      categories = ["Development"];
    };
  };
}
