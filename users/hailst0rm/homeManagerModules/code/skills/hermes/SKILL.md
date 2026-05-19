---
name: hermes
description: Manage and configure the local Hermes AI agent instance by Nous Research on NixOS. Use this skill whenever the user mentions hermes, hermes agent, hermes setup, hermes config, hermes gateway, hermes tools, hermes doctor, SOUL.md, or wants to configure toolsets, API keys, messaging platforms, terminal backends, or MCP servers for Hermes. Also trigger when editing ~/.hermes/config.yaml, nixosModules/services/hermes-agent.nix, sops secrets for hermes, or troubleshooting Hermes tool availability.
origin: custom
---

# Hermes Agent Management (NixOS)

Skill for managing a Hermes agent instance on NixOS with sops-nix secrets and systemd services.

## NixOS Integration

Hermes runs as a NixOS-managed service, not a standalone install:

- **Package**: provided via overlay at `pkgs.hermes-agent` (see `overlays/hermes-agent.nix`)
- **NixOS module**: `nixosModules/services/hermes-agent.nix`
- **Secrets**: managed by sops-nix, NOT `~/.hermes/.env`
- **Services**: systemd units for gateway, dashboard, and signal-cli

### NixOS Options

```nix
services.hermes-agent = {
  enable = true;                    # Enable gateway service
  port = 8333;                      # Gateway port
  signal.enable = true;             # Enable signal-cli daemon
  signal.port = 8080;               # signal-cli HTTP port
  dashboard.enable = true;          # Enable web dashboard
  dashboard.port = 9119;            # Dashboard port
  dashboard.host = "0.0.0.0";      # Dashboard bind address
};
```

### Systemd Services

| Service | Description | Depends on |
|---------|-------------|------------|
| `hermes-agent.service` | Gateway (messaging platforms) | `network.target`, optionally `signal-cli-daemon.service` |
| `hermes-dashboard.service` | Web dashboard | `network.target`, `hermes-agent.service` |
| `signal-cli-daemon.service` | Signal messaging backend | `network.target` |

Manage with standard systemd commands:
```bash
sudo systemctl status hermes-agent
sudo systemctl restart hermes-agent
journalctl -u hermes-agent -f       # Tail gateway logs
journalctl -u hermes-dashboard -f   # Tail dashboard logs
```

### Secrets (sops-nix)

API keys and tokens live in sops-encrypted YAML, NOT in `~/.hermes/.env`. The gateway service loads them via `EnvironmentFile`:

```
config.sops.secrets."services/hermes-agent/env".path    # All API keys as KEY=VALUE
config.sops.secrets."services/signal-cli/account".path  # Signal account number
```

To add or change API keys:
1. Edit the sops secrets file: `sops secrets/<username>.yaml`
2. Add keys under `services/hermes-agent/env` in `KEY=VALUE` format
3. Rebuild: `nh os switch` or `sudo nixos-rebuild switch --flake .#<hostname>`
4. Restart the service: `sudo systemctl restart hermes-agent`

Do NOT edit `~/.hermes/.env` for service-level keys — they get overridden by sops on rebuild.

## Instance Layout

User-facing Hermes state still lives under `~/.hermes/`:

| Path | Purpose |
|------|---------|
| `~/.hermes/config.yaml` | Main configuration (model, terminal, tools, gateway) |
| `~/.hermes/SOUL.md` | Global personality / system prompt |
| `~/.hermes/cron/` | Scheduled task definitions |
| `~/.hermes/sessions/` | Conversation history |
| `~/.hermes/logs/` | Runtime logs |
| `~/.hermes/skills/` | User-created and learned skills |
| `~/.hermes/memory/` | Persistent cross-session memory |

Note: `~/.hermes/.env` exists but is only used for interactive `hermes` chat sessions. The systemd gateway service uses sops secrets instead.

## Common Commands

```bash
# Interactive chat (uses ~/.hermes/.env for keys)
hermes                    # Start interactive chat
hermes doctor             # Diagnose issues

# Configuration
hermes setup              # Full setup wizard
hermes setup model        # Change model/provider
hermes setup terminal     # Change terminal backend
hermes setup gateway      # Configure messaging platforms
hermes setup tools        # Configure tool providers (interactive)
hermes config             # View current settings
hermes config edit        # Open config in editor
hermes config set <k> <v> # Set a specific value

# Tools
hermes tools              # List/configure tool availability
hermes chat --toolsets "web,terminal"  # Use specific toolsets

# Gateway is managed by systemd, not run manually
# Use: sudo systemctl restart hermes-agent
```

## Toolsets

Available toolset categories (enable via `hermes setup tools` or `hermes tools`):

| Toolset | Key Tools | Required Keys / Deps |
|---------|-----------|---------------------|
| `web` / `search` | `web_search`, `web_extract` | `EXA_API_KEY`, `TAVILY_API_KEY`, `SEARXNG_URL`, or others |
| `terminal` / `file` | `terminal`, `process`, `read_file`, `patch` | None (built-in) |
| `browser` | `browser_navigate`, `browser_snapshot` | `npm install -g agent-browser` |
| `vision` | `vision_analyze` | None (built-in) |
| `image_gen` | `image_generate` | `FAL_KEY` or `OPENAI_API_KEY` |
| `tts` | `text_to_speech` | None (Edge TTS built-in) |
| `todo` | Task planning | None (built-in) |
| `skills` | View, create, edit skills | None (built-in) |
| `moa` | Mixture of Agents | `OPENROUTER_API_KEY` |
| `rl` | RL Training (Tinker) | `TINKER_API_KEY` |
| `memory` | Persistent memory | None (built-in) |
| `session_search` | Search past sessions | None (built-in) |
| `discord` / `discord_admin` | Discord integration | Discord bot token |
| `messaging` | Telegram, etc. | Platform tokens in gateway config |
| `homeassistant` | Home Assistant control | HA token + URL |
| `spotify` | Spotify playback | Spotify credentials |
| `mcp-<server>` | MCP server tools | Per-server config |

Required API keys go in sops secrets (for the gateway service) or `~/.hermes/.env` (for interactive chat only).

## Terminal Backends

Configured in `~/.hermes/config.yaml` under `terminal:`:

```yaml
terminal:
  backend: local    # local | docker | ssh | singularity | modal | daytona | vercel_sandbox
  cwd: "."
  timeout: 180
```

## Troubleshooting

- Run `hermes doctor` first for automated diagnostics
- Check systemd logs: `journalctl -u hermes-agent -f`
- Check `~/.hermes/logs/` for interactive session errors
- Missing tools in gateway usually mean missing keys in sops secrets
- Missing tools in interactive chat usually mean missing keys in `~/.hermes/.env`
- After changing `config.yaml`: restart the service (`sudo systemctl restart hermes-agent`)
- After changing NixOS module options: rebuild (`nh os switch`)
- If setup corrupted config, restore backup: `cp ~/.hermes/config.yaml.bak.* ~/.hermes/config.yaml`
