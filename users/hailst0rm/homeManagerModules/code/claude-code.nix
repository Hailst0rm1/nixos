{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  inputs,
  mkSecretEnvWrapper,
  secretPath,
  ...
}: let
  notebooklm-py = pkgs.callPackage ../../../../pkgs/notebooklm-py/package.nix {};
  codeburn = pkgs.callPackage ../../../../pkgs/codeburn/package.nix {};
  rtk = pkgs.callPackage ../../../../pkgs/rtk/package.nix {};

  gsd-repo = pkgs.fetchFromGitHub {
    owner = "gsd-build";
    repo = "get-shit-done";
    rev = "v1.42.3";
    hash = "sha256-ylfH91jnyAkORAlon0CMko48DzeLYvSN1jhyDDKwnWU=";
  };

  # Pinned to a specific commit on `main` instead of `rev = "main"`.
  # With a branch ref, Nix caches the first fetched tree and silently
  # reuses it forever — new upstream commits never reach this build until
  # the hash changes. The repo has no release tags, so this tracks main by
  # SHA. The `# track-branch:` sentinel tells
  # scripts/nix-github-update-report.py to auto-bump `rev`+`hash` to the
  # current branch HEAD on its next sweep.
  # track-branch: main
  mattpocock-skills-repo = pkgs.fetchFromGitHub {
    owner = "mattpocock";
    repo = "skills";
    rev = "694fa30311e02c2639942308513555e61ee84a6f";
    hash = "sha256-NGRKdnHSBKoR48zGotmJ3zGXnQ58ogudv8T4Va/2DSY=";
  };

  mattpocockPlugin = lib.importJSON "${mattpocock-skills-repo}/.claude-plugin/plugin.json";
  # Experimental skills not listed in plugin.json — opt them in explicitly here.
  # Currently empty (teach graduated into plugin.json upstream). The in-progress
  # "review" skill is handled separately below because its name collides with
  # the built-in /review.
  mattpocockExtraSkills = [
  ];
  mattpocockSkillFiles = lib.listToAttrs (map (skillPath: {
      name = ".claude/skills/${baseNameOf skillPath}";
      value.source = "${mattpocock-skills-repo}/${skillPath}";
    })
    (mattpocockPlugin.skills ++ mattpocockExtraSkills));

  # Experimental upstream "review" skill (skills/in-progress/review), renamed
  # to "review-of-all-reviews" so it doesn't collide with the built-in /review
  # (PR review) skill. Claude Code identifies a skill by its frontmatter
  # `name:`, not its directory, so the rename rewrites that line. Copies from
  # the pinned source — still tracks upstream via the track-branch sweep above.
  reviewOfAllReviewsSkill = pkgs.runCommand "review-of-all-reviews-skill" {} ''
    cp -r ${mattpocock-skills-repo}/skills/in-progress/review $out
    chmod -R u+w $out
    ${pkgs.gnused}/bin/sed -i 's/^name: review$/name: review-of-all-reviews/' $out/SKILL.md
  '';

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
    command = "${pkgs.nodejs}/bin/npx -y @colbymchenry/codegraph serve --mcp";
  };

  codegraphCliWrapper = mkSecretEnvWrapper {
    name = "codegraph";
    bin = true;
    command = "${pkgs.nodejs}/bin/npx -y @colbymchenry/codegraph";
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

  githubPatPath = secretPath "services/github/pat";

  # Thin delegator hook for RTK (rtk-ai/rtk). Vendored from
  # hooks/claude/rtk-rewrite.sh in the upstream repo. All rewrite logic lives
  # in `rtk rewrite`; the script just shuttles JSON in/out of Claude Code's
  # PreToolUse hook protocol. Absolute paths (jq, rtk) make the runtime
  # version check + PATH guards from upstream redundant — Nix pins them.
  # rtk currently only ships in nixpkgs-unstable, hence pkgs-unstable here.
  rtkRewriteHook = pkgs.writeShellScript "rtk-rewrite" ''
    INPUT=$(${pkgs.coreutils}/bin/cat)
    CMD=$(${pkgs.jq}/bin/jq -r '.tool_input.command // empty' <<<"$INPUT")

    if [ -z "$CMD" ]; then
      exit 0
    fi

    REWRITTEN=$(${rtk}/bin/rtk rewrite "$CMD" 2>/dev/null)
    EXIT_CODE=$?

    case $EXIT_CODE in
      0)
        # Rewrite found — auto-allow unless output is identical (already RTK).
        [ "$CMD" = "$REWRITTEN" ] && exit 0
        ;;
      1) exit 0 ;;  # No RTK equivalent — pass through.
      2) exit 0 ;;  # Deny rule — let Claude Code's native deny handle it.
      3) ;;          # Ask rule — rewrite but prompt the user.
      *) exit 0 ;;
    esac

    if [ "$EXIT_CODE" -eq 3 ]; then
      ${pkgs.jq}/bin/jq -c --arg cmd "$REWRITTEN" \
        '.tool_input.command = $cmd | {
          "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "updatedInput": .tool_input
          }
        }' <<<"$INPUT"
    else
      ${pkgs.jq}/bin/jq -c --arg cmd "$REWRITTEN" \
        '.tool_input.command = $cmd | {
          "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "allow",
            "permissionDecisionReason": "RTK auto-rewrite",
            "updatedInput": .tool_input
          }
        }' <<<"$INPUT"
    fi
  '';

  # Stop hook: nudge user to run /session-handoff once the session exceeds
  # `sessionHandoffReminder.thresholdMinutes`. Auto-dismisses once the
  # session-handoff skill has actually been invoked (detected via a Skill
  # tool_use entry in the transcript). Every error path exits 0 so this can
  # never disrupt Claude.
  sessionHandoffReminderHook = pkgs.writeShellScript "session-handoff-reminder" ''
    set -eu
    INPUT=$(${pkgs.coreutils}/bin/cat)
    TRANSCRIPT=$(${pkgs.jq}/bin/jq -r '.transcript_path // empty' <<<"$INPUT")
    [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ] || exit 0

    # Transcripts start with several metadata entries (last-prompt,
    # permission-mode, file-history-snapshot) that have timestamp=null.
    # Skip them and take the first real timestamp.
    FIRST_TS=$(${pkgs.jq}/bin/jq -r 'select(.timestamp != null) | .timestamp' "$TRANSCRIPT" 2>/dev/null \
      | ${pkgs.coreutils}/bin/head -n1)
    [ -n "$FIRST_TS" ] || exit 0

    START_EPOCH=$(${pkgs.coreutils}/bin/date -d "$FIRST_TS" +%s 2>/dev/null) || exit 0
    NOW_EPOCH=$(${pkgs.coreutils}/bin/date +%s)
    AGE_MIN=$(( (NOW_EPOCH - START_EPOCH) / 60 ))
    THRESHOLD=${toString config.code.claude-code.sessionHandoffReminder.thresholdMinutes}
    [ "$AGE_MIN" -ge "$THRESHOLD" ] || exit 0

    # Dismiss the reminder once the session-handoff skill was actually invoked.
    # Claude Code records skill invocations as a tool_use block with
    # name="Skill" and input.skill="<skill-name>". This is precise — mere
    # discussion of the skill in chat does not match.
    if ${pkgs.jq}/bin/jq -e '.message?.content?[]? | select(.type? == "tool_use" and .name? == "Skill" and .input?.skill? == "session-handoff")' "$TRANSCRIPT" >/dev/null 2>&1; then
      exit 0
    fi

    HOURS=$((AGE_MIN / 60))
    MINS=$((AGE_MIN % 60))
    # Claude Code's Stop hook discards raw stdout from the user view; the
    # documented way to surface a message in the transcript is JSON with a
    # `systemMessage` field.
    MSG=$(${pkgs.coreutils}/bin/printf '─── Session age: %dh %dm ───\nRun /session-handoff, copy the output, /clear, then paste it into the fresh session.' "$HOURS" "$MINS")
    ${pkgs.jq}/bin/jq -nc --arg msg "$MSG" '{"systemMessage": $msg}'
  '';

  # Sound hook: non-blocking paplay on Stop / Notification. Backgrounded so
  # the hook returns immediately and never delays Claude's next turn.
  # `volumePct` is 0-100; paplay's --volume range is 0-65536 (100% = 65536).
  playSoundHook = name: soundPath: volumePct:
    pkgs.writeShellScript "claude-code-sound-${name}" ''
      ${pkgs.pulseaudio}/bin/paplay --volume=${toString (volumePct * 65536 / 100)} "${soundPath}" >/dev/null 2>&1 &
      disown
      exit 0
    '';

  # Notification variant: suppresses the idle "Claude is waiting for your
  # input" notification Claude Code fires ~60s after Stop. Permission
  # prompts (and any other Notification message) still chime.
  playNotificationSoundHook = soundPath: volumePct:
    pkgs.writeShellScript "claude-code-sound-notification" ''
      INPUT=$(${pkgs.coreutils}/bin/cat)
      MSG=$(${pkgs.jq}/bin/jq -r '.message // empty' <<<"$INPUT")
      case "$MSG" in
        *"waiting for your input"*) exit 0 ;;
      esac
      ${pkgs.pulseaudio}/bin/paplay --volume=${toString (volumePct * 65536 / 100)} "${soundPath}" >/dev/null 2>&1 &
      disown
      exit 0
    '';

  # statusLine: single-line bar fed JSON on stdin by Claude Code.
  # Renders: v<version>  <model>  <hostname>  <project> {<wt>:}<branch>{*}{⇡N}{⇣N}  <ctx%>  +<add>/-<rem>  $<cost>
  # Project = main repo basename (via git-common-dir, stable across worktrees).
  # Worktree label only when GIT_DIR != GIT_COMMON_DIR and not a submodule.
  # ANSI colors only — no OSC, no Nerd Font PUA.
  claudeStatuslineScript = pkgs.writeShellScript "claude-statusline" ''
    set -uo pipefail

    RESET=$'\033[0m'
    DIM=$'\033[2m'
    CYAN=$'\033[36m'
    BLUE=$'\033[34m'
    MAGENTA=$'\033[35m'
    YELLOW=$'\033[33m'
    GREEN=$'\033[32m'
    RED=$'\033[31m'
    ORANGE=$'\033[38;5;208m'

    INPUT=$(${pkgs.coreutils}/bin/cat)
    JQ=${pkgs.jq}/bin/jq
    GIT=${pkgs.git}/bin/git

    VERSION=$(echo "$INPUT" | "$JQ" -r '.version // "?"')
    MODEL=$(echo "$INPUT" | "$JQ" -r '.model.display_name // "?"')
    HOST=$(${pkgs.coreutils}/bin/uname -n)

    PROJECT=""
    GIT_SEG=""
    WT_LABEL=""

    if "$GIT" rev-parse --git-dir >/dev/null 2>&1; then
      # Project: parent of shared .git/ — stable across worktrees.
      COMMON=$("$GIT" rev-parse --git-common-dir 2>/dev/null)
      COMMON_ABS=""
      if [ -n "$COMMON" ]; then
        COMMON_ABS=$(cd "$COMMON" 2>/dev/null && pwd -P || echo "")
        if [ -n "$COMMON_ABS" ]; then
          MAIN_ROOT=$(${pkgs.coreutils}/bin/dirname "$COMMON_ABS")
          PROJECT=$(${pkgs.coreutils}/bin/basename "$MAIN_ROOT")
        fi
      fi

      # Worktree detection: GIT_DIR != GIT_COMMON_DIR AND not a submodule.
      GIT_DIR_PATH=$(cd "$("$GIT" rev-parse --git-dir)" 2>/dev/null && pwd -P || echo "")
      SUPER=$("$GIT" rev-parse --show-superproject-working-tree 2>/dev/null)
      if [ -n "$GIT_DIR_PATH" ] && [ -n "$COMMON_ABS" ] \
           && [ "$GIT_DIR_PATH" != "$COMMON_ABS" ] && [ -z "$SUPER" ]; then
        WT_ROOT=$("$GIT" rev-parse --show-toplevel 2>/dev/null)
        if [ -n "$WT_ROOT" ]; then
          WT_NAME=$(${pkgs.coreutils}/bin/basename "$WT_ROOT")
          WT_LABEL="''${YELLOW}''${WT_NAME}''${RESET}:"
        fi
      fi

      BR=$("$GIT" branch --show-current 2>/dev/null)
      [ -z "$BR" ] && BR="(detached)"

      DIRTY=""
      if [ -n "$("$GIT" status --porcelain 2>/dev/null)" ]; then
        DIRTY="''${YELLOW}*''${RESET}''${MAGENTA}"
      fi

      UP=""
      if "$GIT" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
        AHEAD=$("$GIT" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)
        BEHIND=$("$GIT" rev-list --count 'HEAD..@{u}' 2>/dev/null || echo 0)
        [ "$AHEAD"  -gt 0 ] && UP="''${UP}⇡''${AHEAD}"
        [ "$BEHIND" -gt 0 ] && UP="''${UP}⇣''${BEHIND}"
      fi
      GIT_SEG=" ''${WT_LABEL}''${MAGENTA}''${BR}''${DIRTY}''${UP}''${RESET}"
    fi

    # Non-git fallback for project name.
    if [ -z "$PROJECT" ]; then
      PROJECT_PATH=$(echo "$INPUT" | "$JQ" -r '.workspace.project_dir // .cwd // ""')
      [ -n "$PROJECT_PATH" ] && PROJECT=$(${pkgs.coreutils}/bin/basename "$PROJECT_PATH")
    fi
    [ -z "$PROJECT" ] && PROJECT="?"

    CTX=$(echo "$INPUT" | "$JQ" -r '.context_window.used_percentage // 0' \
            | ${pkgs.coreutils}/bin/cut -d. -f1)
    if   [ "$CTX" -ge 80 ]; then CTX_COLOR="$RED"
    elif [ "$CTX" -ge 50 ]; then CTX_COLOR="$YELLOW"
    else                         CTX_COLOR="$GREEN"
    fi

    ADD=$(echo "$INPUT" | "$JQ" -r '.cost.total_lines_added   // 0')
    REM=$(echo "$INPUT" | "$JQ" -r '.cost.total_lines_removed // 0')

    COST=$(echo "$INPUT" | "$JQ" -r '.cost.total_cost_usd // 0')
    COST_CENT=$(echo "$INPUT" | "$JQ" -r '(.cost.total_cost_usd // 0) * 100 | floor')
    if   [ "$COST_CENT" -ge 200 ]; then COST_COLOR="$RED"
    elif [ "$COST_CENT" -ge 50  ]; then COST_COLOR="$YELLOW"
    else                                COST_COLOR="$GREEN"
    fi
    COST_FMT=$(${pkgs.coreutils}/bin/printf '%.2f' "$COST")

    # Rate-limit segments — silent when rate_limits absent (older Claude Code, fixtures).
    fmt_delta() {
      local d=$1
      if [ "$d" -le 0 ]; then echo "now"; return; fi
      if [ "$d" -ge 86400 ]; then echo "$((d/86400))d$((d%86400/3600))h"; return; fi
      if [ "$d" -ge 3600  ]; then echo "$((d/3600))h$((d%3600/60))m";    return; fi
      echo "$((d/60))m"
    }

    NOW=$(${pkgs.coreutils}/bin/date +%s)
    rate_seg() {
      local path=$1 label=$2
      local pct pct_int ts color delta countdown epoch
      pct=$(echo "$INPUT" | "$JQ" -r "$path.used_percentage // empty")
      [ -z "$pct" ] && return
      ts=$(echo "$INPUT" | "$JQ" -r "$path.resets_at // empty")

      pct_int=''${pct%%.*}
      if   [ "$pct_int" -ge 80 ]; then color="$RED"
      elif [ "$pct_int" -ge 50 ]; then color="$YELLOW"
      else                             color="$GREEN"
      fi

      countdown=""
      if [ -n "$ts" ]; then
        # resets_at is Unix epoch seconds in live v2.1.150+ payload; ISO 8601 is
        # forward-compat fallback for any future schema change.
        if [[ "$ts" =~ ^[0-9]+$ ]]; then
          epoch="$ts"
        else
          epoch=$(${pkgs.coreutils}/bin/date -d "$ts" +%s 2>/dev/null || echo "")
        fi
        if [ -n "$epoch" ]; then
          delta=$((epoch - NOW))
          countdown=" ($(fmt_delta "$delta"))"
        fi
      fi

      printf '   %s%s:%s%%%s%s' "$color" "$label" "$pct_int" "$countdown" "$RESET"
    }

    RATE_5H=$(rate_seg '.rate_limits.five_hour' '5h')
    RATE_7D=$(rate_seg '.rate_limits.seven_day' '7d')

    ${pkgs.coreutils}/bin/printf '%sv%s%s   %s%s%s   %s%s%s   %s%s%s%s   %s%s%%%s   %s+%s%s/%s-%s%s   %s$%s%s%s%s\n' \
      "$DIM" "$VERSION" "$RESET" \
      "$CYAN" "$MODEL" "$RESET" \
      "$ORANGE" "$HOST" "$RESET" \
      "$BLUE" "$PROJECT" "$RESET" "$GIT_SEG" \
      "$CTX_COLOR" "$CTX" "$RESET" \
      "$GREEN" "$ADD" "$RESET" "$RED" "$REM" "$RESET" \
      "$COST_COLOR" "$COST_FMT" "$RESET" "$RATE_5H" "$RATE_7D"
  '';
in {
  options.code.claude-code = {
    enable = lib.mkEnableOption "Enable Claude Code CLI";
    n8n.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable n8n MCP server and skills for Claude Code.";
    };
    exa.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the Exa web/code search MCP server for Claude Code.";
    };
    context7.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the Context7 (upstash/context7) MCP server: on-demand up-to-date library documentation. Reads CONTEXT7_API_KEY from sops services/context7/api-key — falls through to anonymous (lower rate limits) if the secret file is missing.";
    };
    codegraph.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Enable the colbymchenry/codegraph MCP server: tree-sitter + SQLite/FTS5 code-intelligence with symbol search, callers/callees, and impact analysis. Runs as a global MCP server; only does useful work in projects that have been initialized with `codegraph init` (creates `.codegraph/`). 100% local, no API keys. Supports TS/JS, Python, Go, Rust, Java, C#, PHP, Ruby, C/C++, Swift, Kotlin, Dart, Lua, Luau, Svelte, Liquid, Pascal — NOT Nix.
      '';
    };
    perplexity.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the Perplexity web search MCP server for Claude Code.";
    };
    printing-press.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the cli-printing-press Claude Code plugin (marketplace + generator skills) and the Go toolchain it needs.";
    };
    playground.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the Anthropic-verified playground plugin (playground@claude-plugins-official): /playground generates self-contained interactive HTML playgrounds (design, data explorer, concept map, document critique, diff review, code map) with live preview and copyable prompt output.";
    };
    visual-explainer.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the nicobailon/visual-explainer plugin: slash commands (/generate-web-diagram, /generate-slides, /diff-review, /plan-review, etc.) that produce standalone HTML pages for diagrams, diff/plan reviews, slides, and data tables.";
    };
    codex.enable = lib.mkOption {
      type = lib.types.bool;
      default = config.code.codex.enable;
      description = ''
        Enable the openai/codex-plugin-cc plugin for Claude Code (slash commands /codex:setup, /codex:review, /codex:status, /codex:result and the codex:codex-rescue subagent). The plugin shells out to the local Codex CLI; defaults to whatever `code.codex.enable` is set to so the binary is present.
      '';
    };
    claude-mem.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Enable the thedotmack/claude-mem plugin: persistent memory across Claude Code sessions. Captures tool-use observations, compresses them with an AI provider, and re-injects relevant context on session start. Hooks and worker live entirely under ~/.claude/plugins/marketplaces/thedotmack/ (mutable, not nix-managed), so it coexists with the nix-rendered settings.json. Requires `node` (already provided) and an AI provider configured at runtime — see https://docs.claude-mem.ai.
      '';
    };
    tokenOptimizer.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable the alexgreensh/token-optimizer plugin: monthly-cadence context audits and health reports. Provides slash commands /token-optimizer, /coach, /memory-review, /attention-score, /drift, /triage, /doctor, /quality, /report, /savings, /jsonl-inspect. Layer A only — marketplace registration + plugin enablement. Deliberately does NOT run the upstream setup-hook/setup-smart-compact/setup-daemon/setup-quality-bar scripts, which would mutate ~/.claude/settings.json (a /nix/store symlink). One-shot dashboard via `python3 measure.py dashboard --serve` when needed. License: PolyForm Noncommercial — personal use only.
      '';
    };
    rtk.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable RTK (rtk-ai/rtk): CLI proxy + Claude Code PreToolUse hook that rewrites common dev commands (git/cat/grep/test runners) to compact RTK equivalents for 60-90% token savings on Bash tool calls. Measure with `rtk gain` after a few sessions.";
    };
    sessionHandoffReminder = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Print a reminder after every Claude turn once the session exceeds thresholdMinutes, suggesting /session-handoff then /clear. Auto-dismisses once the session-handoff skill has produced its template this session.";
      };
      thresholdMinutes = lib.mkOption {
        type = lib.types.int;
        default = 60;
        description = "Minutes of session age before the reminder starts firing.";
      };
    };
    sound = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Play a short system sound when Claude finishes a turn (Stop) and when Claude needs a permission decision (Notification). Idle 'waiting for input' notifications are filtered out.";
      };
      stopSound = lib.mkOption {
        type = lib.types.path;
        default = "${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/complete.oga";
        defaultText = lib.literalExpression ''"\''${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/complete.oga"'';
        description = "Sound file played on the Stop event (Claude finished a turn).";
      };
      notificationSound = lib.mkOption {
        type = lib.types.path;
        default = "${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/bell.oga";
        defaultText = lib.literalExpression ''"\''${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/bell.oga"'';
        description = "Sound file played on the Notification event (permission prompts). Idle 'waiting for input' notifications are suppressed.";
      };
      volume = lib.mkOption {
        type = lib.types.ints.between 0 100;
        default = 55;
        description = "Playback volume as a percentage (0-100). Applied to both stopSound and notificationSound.";
      };
    };
    localLlm = {
      enable = lib.mkEnableOption "Route Claude Code through a local LLM (e.g. Ollama) by setting ANTHROPIC_* env vars in the user session.";
      authToken = lib.mkOption {
        type = lib.types.str;
        default = "ollama";
        description = "Value for ANTHROPIC_AUTH_TOKEN when localLlm.enable is true.";
      };
      apiKey = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Value for ANTHROPIC_API_KEY when localLlm.enable is true. Empty string explicitly clears any inherited key.";
      };
      baseUrl = lib.mkOption {
        type = lib.types.str;
        default = "http://localhost:11434";
        description = "Value for ANTHROPIC_BASE_URL when localLlm.enable is true. Point this at your Ollama (or compatible) endpoint.";
      };
    };
  };

  config = lib.mkIf config.code.claude-code.enable {
    # Ensure direnv is active inside Claude's shell environment so
    # project-specific shell.nix / flake.nix envs are available to tool calls
    programs.zsh.envExtra = lib.mkAfter ''
      if command -v direnv >/dev/null; then
        if [[ -n "$CLAUDECODE" ]]; then
          eval "$(direnv hook zsh)"
          eval "$(DIRENV_LOG_FORMAT= direnv export zsh)"
          direnv status --json | ${pkgs.jq}/bin/jq -e ".state.foundRC.allowed==0" >/dev/null || direnv allow >/dev/null 2>&1
        fi
      fi
    '';

    programs.claude-code = {
      enable = true;
      package = inputs.claude-code-nix.packages.x86_64-linux.default;

      # Skills (managed via skillsDir, see ./skills/)
      skillsDir = ./skills;

      # Global behavioral guidelines (Karpathy-inspired) → ~/.claude/CLAUDE.md
      memory.text = ''
        # CLAUDE.md

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

      # ~/.claude/rules/*.md — nix-ecosystem is always present; rtk only when
      # code.claude-code.rtk.enable is on.
      rules =
        {
          nix-ecosystem = ''
            # Nix Ecosystem

            General knowledge for working in any Nix-based environment.

            ## Package Discovery & Experimentation
            - Search for packages: `nix search nixpkgs <query>`
            - Try a package without installing: `nix shell nixpkgs#<package>` or `nix run nixpkgs#<package>`
            - Check package info: `nix eval nixpkgs#<package>.meta.description`
            - Use the MCP nixos tool to search packages, options, and documentation

            ## Development Environments with direnv
            Add a `shell.nix` or `default.nix` to the project directory:
            ```nix
            # save as shell.nix
            { pkgs ? import <nixpkgs> {}}:
            pkgs.mkShell {
              packages = [ pkgs.hello ];
            }
            ```
            Then enable direnv:
            ```shell
            echo "use nix" >> .envrc
            direnv allow
            ```
            For flake-based projects, use `use flake` instead of `use nix` in `.envrc`.

            ## Flakes
            - `nix flake show` — inspect flake outputs
            - `nix flake check` — validate a flake
            - `nix flake update` — update all inputs
            - `nix flake lock --update-input <input>` — update a single input

            ## Secrets Management
            - Use sops-nix for managing secrets in NixOS configurations
            - Never hardcode credentials or sensitive data
            - Secret files are encrypted at rest and decrypted at activation time
            - Access secrets via `config.sops.secrets.<name>.path`

            ## Debugging
            - `nix repl` — interactive Nix evaluator; load a flake with `:lf .`
            - `nix eval` — evaluate an expression without building
            - `nix build --print-build-logs` — see full build output
            - `nixos-rebuild build` — verify a NixOS config builds without switching

            ## Security
            - Follow OPSEC principles in all code
            - Think adversarially about code execution
            - Consider defensive coding practices
            - Document security implications of changes
          '';
        }
        // lib.optionalAttrs config.code.claude-code.rtk.enable {
          rtk = ''
            # RTK (Token-Compact Command Proxy)

            A PreToolUse hook silently rewrites your Bash commands to `rtk`
            equivalents (e.g. `git status` → `rtk git status`) for 60-90% token
            savings. You don't need to call `rtk` explicitly — the rewrite is
            transparent.

            Only Bash tool calls go through the hook. The native `Read`, `Grep`,
            and `Glob` tools bypass it, so use shell commands (`cat`, `rg`,
            `find`) or explicit `rtk read`/`rtk grep`/`rtk find` when you want
            RTK filtering on those workflows.

            On test failures the full unfiltered output is saved to
            `~/.local/share/rtk/tee/` — read that log instead of re-running the
            test.

            Useful meta-commands:
            - `rtk gain`      — token-savings summary
            - `rtk discover`  — find commands you could have rewritten
            - `rtk session`   — adoption across recent sessions
          '';
        }
        // lib.optionalAttrs config.code.claude-code.codegraph.enable {
          codegraph = ''
            # CodeGraph (Semantic Code Intelligence)

            When a project contains a `.codegraph/` directory, prefer the
            `mcp__codegraph__*` tools over `grep`/`rg`/`Read` for code
            exploration:

            - `codegraph_search` — find a symbol by name (function, class, method)
            - `codegraph_context` — build a context bundle for a task (entry points + related code)
            - `codegraph_callers` / `codegraph_callees` — call-graph traversal
            - `codegraph_impact` — what breaks if I change this symbol?
            - `codegraph_files` — file/dir structure with symbol counts
            - `codegraph_status` — index health

            One CodeGraph call typically replaces dozens of grep + Read
            exploration steps.

            If a project is NOT initialized, the tools return "CodeGraph not
            initialized" — run `codegraph init` in that project's root
            (optionally `codegraph init --index` to also build the initial
            index). The file watcher keeps the index fresh.

            CodeGraph does not parse Nix — fall back to grep/Read for `.nix`
            files.
          '';
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

      # MCP (Model Context Protocol) servers
      mcpServers =
        {
          nixos = {
            command = "nix";
            args = ["run" "github:utensils/mcp-nixos" "--"];
          };
        }
        // lib.optionalAttrs config.code.claude-code.exa.enable {
          exa = {
            command = "${exaMcpWrapper}";
            args = [];
          };
        }
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
        // lib.optionalAttrs config.code.claude-code.perplexity.enable {
          perplexity = {
            command = "${perplexityMcpWrapper}";
            args = [];
          };
        }
        // lib.optionalAttrs config.code.claude-code.n8n.enable {
          n8n = {
            command = "${n8nMcpWrapper}";
            args = [];
          };
        };

      # Additional settings
      settings = {
        showThinkingSummaries = true;
        cleanupPeriodDays = 14;
        includeCoAuthoredBy = false;
        skipDangerousModePermissionPrompt = true;

        worktree = {
          bgIsolation = "none";
        };

        statusLine = {
          type = "command";
          command = "${claudeStatuslineScript}";
          padding = 0;
        };

        permissions = {
          defaultMode = "bypassPermissions";
          allow =
            [
              "Read"
              "Glob"
              "Grep"
              "LS"
              "Edit"
              "MultiEdit"
              "Write"
              "Bash(git status)"
              "Bash(git diff *)"
              "Bash(git log *)"
              "Bash(git add *)"
              "Bash(git commit *)"
              "Bash(git checkout *)"
              "Bash(git branch *)"
              "Bash(nix *)"
              "Bash(nixfmt *)"
              "Bash(nixos-rebuild build *)"
            ]
            ++ lib.optionals config.code.claude-code.codegraph.enable [
              "mcp__codegraph__codegraph_search"
              "mcp__codegraph__codegraph_context"
              "mcp__codegraph__codegraph_callers"
              "mcp__codegraph__codegraph_callees"
              "mcp__codegraph__codegraph_impact"
              "mcp__codegraph__codegraph_node"
              "mcp__codegraph__codegraph_status"
              "mcp__codegraph__codegraph_files"
            ];
          deny = [
            "Bash(sops:*)"
            "Bash(age:*)"
            "Read(/run/secrets/**)"
            "Read(/run/secrets.d/**)"
            "Read(/home/hailst0rm/.config/sops/**)"
            "Read(/home/hailst0rm/.config/sops-nix/**)"
          ];
        };

        env =
          {
            CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR = "1";
            CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
          }
          // (
            if config.code.claude-code.localLlm.enable
            then {
              # Local LLM (Ollama): no use for Anthropic cloud features, so
              # suppress ALL nonessential traffic. The blanket flag also kills
              # the GrowthBook feature-flag fetch — fine here, we don't want
              # cloud features anyway.
              CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
            }
            else {
              # Cloud (default): we want /ultraplan + other GrowthBook-gated
              # cloud features. Claude Code couples its telemetry opt-out to the
              # GrowthBook feature-flag fetch via ONE shared kill switch (fW()),
              # so DISABLE_TELEMETRY — and the NONESSENTIAL blanket — silently
              # block those features. Telemetry is OFF BY DEFAULT anyway (only
              # sent with CLAUDE_CODE_ENABLE_TELEMETRY + an OTEL exporter), so
              # omitting DISABLE_TELEMETRY costs no real privacy while restoring
              # the flag fetch. See anthropics/claude-code#45918 and #34178
              # (closed wontfix). The flags below are independent of that switch:
              DISABLE_ERROR_REPORTING = "1"; # no Sentry crash reports
              DISABLE_FEEDBACK_COMMAND = "1"; # no /bug submission
              DISABLE_AUTOUPDATER = "1"; # moot on a Nix-managed install anyway
            }
          );

        # Hooks:
        # - PreToolUse (RTK): rewrites Bash commands to token-compact equivalents.
        # - Stop (session-handoff reminder): nudges user to wrap up + /clear after threshold.
        hooks = lib.mkMerge [
          (lib.mkIf config.code.claude-code.rtk.enable {
            PreToolUse = [
              {
                matcher = "Bash";
                hooks = [
                  {
                    type = "command";
                    command = "${rtkRewriteHook}";
                  }
                ];
              }
            ];
          })
          (lib.mkIf config.code.claude-code.sessionHandoffReminder.enable {
            Stop = [
              {
                hooks = [
                  {
                    type = "command";
                    command = "${sessionHandoffReminderHook}";
                  }
                ];
              }
            ];
          })
          (lib.mkIf config.code.claude-code.sound.enable {
            Stop = [
              {
                hooks = [
                  {
                    type = "command";
                    command = "${playSoundHook "stop" config.code.claude-code.sound.stopSound config.code.claude-code.sound.volume}";
                  }
                ];
              }
            ];
            Notification = [
              {
                hooks = [
                  {
                    type = "command";
                    command = "${playNotificationSoundHook config.code.claude-code.sound.notificationSound config.code.claude-code.sound.volume}";
                  }
                ];
              }
            ];
          })
        ];

        # Plugins
        enabledPlugins =
          {
            "skill-creator@claude-plugins-official" = true;
            "superpowers@claude-plugins-official" = true;
            # "frontend-design@claude-plugins-official" = true;  # Replaced by impeccable (strict superset)
            "impeccable@impeccable" = true;
            "obsidian@obsidian-skills" = true;
            "context-mode@context-mode" = true;
          }
          // lib.optionalAttrs config.code.claude-code.playground.enable {
            "playground@claude-plugins-official" = true;
          }
          // lib.optionalAttrs config.code.claude-code.visual-explainer.enable {
            "visual-explainer@visual-explainer-marketplace" = true;
          }
          // lib.optionalAttrs config.code.claude-code.n8n.enable {
            "n8n-skills@n8n-skills" = true;
          }
          // lib.optionalAttrs config.code.claude-code.printing-press.enable {
            "cli-printing-press@cli-printing-press" = true;
          }
          // lib.optionalAttrs config.code.claude-code.codex.enable {
            "codex@openai-codex" = true;
          }
          // lib.optionalAttrs config.code.claude-code.claude-mem.enable {
            "claude-mem@thedotmack" = true;
          }
          // lib.optionalAttrs config.code.claude-code.tokenOptimizer.enable {
            "token-optimizer@alexgreensh-token-optimizer" = true;
          };

        extraKnownMarketplaces =
          {
            claude-plugins-official = {
              source = {
                source = "github";
                repo = "anthropics/claude-plugins-official";
              };
            };
            obsidian-skills = {
              source = {
                source = "github";
                repo = "kepano/obsidian-skills";
              };
            };
            context-mode = {
              source = {
                source = "github";
                repo = "mksglu/context-mode";
              };
            };
            impeccable = {
              source = {
                source = "github";
                repo = "pbakaus/impeccable";
              };
            };
          }
          // lib.optionalAttrs config.code.claude-code.visual-explainer.enable {
            visual-explainer-marketplace = {
              source = {
                source = "github";
                repo = "nicobailon/visual-explainer";
              };
            };
          }
          // lib.optionalAttrs config.code.claude-code.n8n.enable {
            n8n-skills = {
              source = {
                source = "github";
                repo = "czlonkowski/n8n-skills";
              };
            };
          }
          // lib.optionalAttrs config.code.claude-code.printing-press.enable {
            cli-printing-press = {
              source = {
                source = "github";
                repo = "mvanhorn/cli-printing-press";
              };
            };
          }
          // lib.optionalAttrs config.code.claude-code.codex.enable {
            openai-codex = {
              source = {
                source = "github";
                repo = "openai/codex-plugin-cc";
              };
            };
          }
          // lib.optionalAttrs config.code.claude-code.claude-mem.enable {
            thedotmack = {
              source = {
                source = "github";
                repo = "thedotmack/claude-mem";
              };
            };
          }
          // lib.optionalAttrs config.code.claude-code.tokenOptimizer.enable {
            alexgreensh-token-optimizer = {
              source = {
                source = "github";
                repo = "alexgreensh/token-optimizer";
              };
            };
          };

        # Editor preferences (if claude-code supports this)
        editor = {
          tabSize = 4;
          insertSpaces = true;
        };

        # Terminal preferences
        terminal = {
          shell = "${pkgs.zsh}/bin/zsh";
        };
      };
    };

    # GSD (Get Shit Done) commands and agents +
    # Matt Pocock skills (flat-linked from upstream plugin.json — 15 stable + 1 in-progress (review))
    home.file =
      {
        ".claude/commands/gsd".source = "${gsd-repo}/commands/gsd";
        ".claude/agents" = {
          source = "${gsd-repo}/agents";
          recursive = true;
        };
        ".claude/skills/review-of-all-reviews".source = reviewOfAllReviewsSkill;
      }
      // mattpocockSkillFiles;

    # VS Code settings for Claude Code extension (only when VS Code is enabled)
    programs.vscode.profiles.default.userSettings = lib.mkIf config.code.vscode.enable {
      "claudeCode.allowDangerouslySkipPermissions" = true;
      "claudeCode.enableNewConversationShortcut" = true;
      "claudeCode.claudeProcessWrapper" = "${config.programs.claude-code.finalPackage}/bin/claude";
    };

    # Ensure required dependencies are available
    home.packages = with pkgs;
      [
        uv # For Python MCP servers
        nodejs # For npm/npx MCP servers
        git # For git MCP server

        # NotebookLM automation CLI
        notebooklm-py

        # Brave for the Claude browser extension
        brave

        # AI coding token usage tracker
        codeburn
      ]
      ++ lib.optionals config.code.claude-code.sound.enable [
        sound-theme-freedesktop # complete.oga / bell.oga for Claude Code Stop + Notification hooks
      ]
      ++ lib.optionals config.code.claude-code.printing-press.enable [
        go # /printing-press generator shells out to `go install`/`go build`
      ]
      ++ lib.optionals config.code.claude-code.rtk.enable [
        rtk # Token-compact CLI proxy invoked by rtkRewriteHook + meta-commands (`rtk gain`, etc.). Built from pkgs/rtk/package.nix.
      ]
      ++ lib.optionals config.code.claude-code.claude-mem.enable [
        bun # claude-mem's hooks shell out to `bun` via scripts/bun-runner.js
      ]
      ++ lib.optionals config.code.claude-code.codegraph.enable [
        codegraphCliWrapper # `codegraph` CLI for `codegraph init`/`init --index` in project roots
      ];

    # Pick up *-pp-cli binaries that `/printing-press` installs into ~/go/bin
    home.sessionPath = lib.mkIf config.code.claude-code.printing-press.enable ["$HOME/go/bin"];

    home.sessionVariables = lib.mkIf config.code.claude-code.localLlm.enable {
      ANTHROPIC_AUTH_TOKEN = config.code.claude-code.localLlm.authToken;
      ANTHROPIC_API_KEY = config.code.claude-code.localLlm.apiKey;
      ANTHROPIC_BASE_URL = config.code.claude-code.localLlm.baseUrl;
    };
  };
}
