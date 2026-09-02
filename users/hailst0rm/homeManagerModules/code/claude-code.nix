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
  rtk = pkgs-unstable.rtk; # official pkg (unstable ships 0.45.0; stable 26.05 lags at 0.41.0)
  twentyfirst-cli = pkgs.callPackage ../../../../pkgs/21st-cli/package.nix {};
  # `shadcn-index` gives shadcn the global search it lacks; it shells out to the
  # same (unstable) shadcn the option below puts on PATH, so pin them together.
  shadcn-index = pkgs.callPackage ../../../../pkgs/shadcn-index/package.nix {inherit (pkgs-unstable) shadcn;};
  higgsfield-cli = pkgs.callPackage ../../../../pkgs/higgsfield-cli/package.nix {};

  # The `21st` CLI is a superset of 21st.dev's MCP server (same endpoint, same
  # login), so we take the CLI + its skills instead of the MCP server: an MCP
  # server's tool schemas sit in the system prompt on every turn, a skill's
  # body only loads when the skill fires. Skill names come from the package, so
  # adding one upstream needs no change here. Refresh with pkgs/21st-cli/update.sh.
  twentyfirstSkillFiles = lib.optionalAttrs config.code.claude-code.twentyfirst.enable (
    lib.listToAttrs (map (name: {
        name = ".claude/skills/${name}";
        value.source = "${twentyfirst-cli}/share/claude-skills/${name}";
      })
      twentyfirst-cli.skillNames)
  );

  # MCP (Model Context Protocol) servers.
  #
  # Deliberately NOT assigned to `programs.claude-code.mcpServers`: that option
  # exists only to make home-manager attach `--mcp-config` to the `claude`
  # wrapper, and it does so with `--append-flags`, landing the flag *after*
  # "$@". Interactive `claude` and `claude -p "…"` survive that (the prompt is
  # positional), but every subcommand parses the flag as one of its own:
  #
  #   $ claude plugin list  → error: unknown option '--mcp-config'
  #   $ claude mcp list     → error: unknown option '--mcp-config'
  #
  # which is why claude-plugins-update.nix has to reach past the wrapper for
  # the unwrapped binary. Prepending alone does not fix it either: the flag is
  # variadic, so `--mcp-config <file> plugin list` swallows `plugin` and `list`
  # as two more config paths. Only the `--flag=value` form binds exactly one
  # value and leaves the subcommand intact.
  #
  # So we leave `mcpServers` empty (home-manager then wraps nothing and takes
  # `package` through as-is) and hand it a package we wrapped ourselves, below.
  # Verified 2026-08-26: `plugin list`, `mcp list` and `-p` all work.
  # Revert to the plain option once home-manager switches to `--add-flags` and
  # the `=` form upstream.
  claudeMcpServers =
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

  claudeMcpConfigFile =
    (pkgs.formats.json {}).generate "claude-code-mcp-config.json"
    {mcpServers = claudeMcpServers;};

  claudeCodePkg = inputs.claude-code-nix.packages.x86_64-linux.default;

  claudeCodeWrapped = pkgs.symlinkJoin {
    name = "claude-code";
    paths = [claudeCodePkg];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = ''
      wrapProgram $out/bin/claude --add-flags "--mcp-config=${claudeMcpConfigFile}"
    '';
    inherit (claudeCodePkg) meta;
  };

  gsd-repo = pkgs.fetchFromGitHub {
    owner = "gsd-build";
    repo = "get-shit-done";
    rev = "v1.42.3";
    hash = "sha256-ylfH91jnyAkORAlon0CMko48DzeLYvSN1jhyDDKwnWU=";
  };

  # Pinned to a specific commit on `main` instead of `rev = "main"`.
  # With a branch ref, Nix caches the first fetched tree and silently
  # reuses it forever — new upstream commits never reach this build until
  # the hash changes. We deliberately track `main` by SHA rather than pin a
  # release tag, to pick up new skills as they land. The `# track-branch:`
  # sentinel tells scripts/nix-github-update-report.py to auto-bump
  # `rev`+`hash` to the current branch HEAD on its next sweep.
  # track-branch: main
  mattpocock-skills-repo = pkgs.fetchFromGitHub {
    owner = "mattpocock";
    repo = "skills";
    rev = "5b15a47f2d7150f545fbcacbfe381787fc0230dc";
    hash = "sha256-FPAAotNqA5aHrFDlj/XddoLs4TDKi+4J5H/mvevlOlk=";
  };

  mattpocockPlugin = lib.importJSON "${mattpocock-skills-repo}/.claude-plugin/plugin.json";
  # Experimental skills not listed in plugin.json — opt them in explicitly here.
  # (As upstream promotes in-progress skills into engineering/ + plugin.json they
  # install automatically and must be dropped from this list — e.g. /implement,
  # and as of v1.1.0 /code-review (was in-progress/review) and /wayfinder (was
  # in-progress/wayfinder, whose old path no longer exists), /resolving-merge-conflicts
  # which upstream registered in plugin.json as of 66898f6, and as of v1.2.2
  # /wizard (was in-progress/wizard, whose old path no longer exists).)
  mattpocockExtraSkills = [
    "skills/in-progress/loop-me"
    "skills/in-progress/claude-handoff"
  ];
  mattpocockSkillFiles = lib.listToAttrs (map (skillPath: {
      name = ".claude/skills/${baseNameOf skillPath}";
      value.source = "${mattpocock-skills-repo}/${skillPath}";
    })
    (mattpocockPlugin.skills ++ mattpocockExtraSkills));

  # Excalidraw's export API as a self-contained ES module (zero imports, 231
  # woff2 faces inlined), for the excalidraw-diagram skill's renderer. Vendored
  # rather than imported from esm.sh, which serves a module graph of
  # root-relative specifiers that 404 against a local origin.
  #
  # Deliberately a prerelease, and NOT to be "corrected" to 0.1.2: 0.1.2 is the
  # newest stable but dates from 2022, and its bundled core computes text `y`
  # from the legacy `baseline` element property that current Excalidraw files no
  # longer carry — every text element renders at y=NaN, overprinting multi-line
  # text on one line. 0.1.3-test32 (2025-04) is the newest published standalone
  # build with a current core.
  excalidrawUtilsRelease = "0.1.3-test32";
  excalidrawUtils = pkgs.fetchurl {
    url = "https://unpkg.com/@excalidraw/utils@${excalidrawUtilsRelease}/dist/prod/index.js";
    hash = "sha256-d1+92GexeP6Pmo0zTNAR6/V8ZznozDi2epxSSNC99Sc=";
    name = "excalidraw-utils-${excalidrawUtilsRelease}.js";
  };

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

  # Telemetry is opt-OUT and defaults to on: the interactive `codegraph install`
  # is what asks for consent, and we wire the MCP server declaratively instead,
  # so it would never be asked. Scoped to these wrappers rather than a global
  # DO_NOT_TRACK, which would silently retune every other tool on the system.
  codegraphStaticEnv.CODEGRAPH_TELEMETRY = "0";

  codegraphMcpWrapper = mkSecretEnvWrapper {
    name = "codegraph-mcp-wrapper";
    staticEnv = codegraphStaticEnv;
    command = "${pkgs.nodejs}/bin/npx -y @colbymchenry/codegraph serve --mcp";
  };

  codegraphCliWrapper = mkSecretEnvWrapper {
    name = "codegraph";
    bin = true;
    staticEnv = codegraphStaticEnv;
    command = "${pkgs.nodejs}/bin/npx -y @colbymchenry/codegraph";
  };

  # Builds a codegraph index for a freshly created worktree (or clone). The
  # index is data *about a specific checkout*, so it cannot be shared or copied
  # the way a file can — it has to be generated at the moment the checkout
  # appears, which is the one thing only a post-checkout hook can do.
  #
  # With codegraph disabled the body degenerates to "chain and exit". That is
  # deliberate: core.hooksPath below is set unconditionally, so git consults
  # ONLY this directory — dropping the hook entirely would silently kill every
  # repo-local post-checkout hook on the machine.
  #
  # Deliberately NOT delivered via init.templateDir: git recreates template
  # symlinks rather than copying them, so every repo would end up pointing at a
  # /nix/store path that a garbage collection later breaks. core.hooksPath is
  # read fresh on every invocation, so there is nothing to go stale, and it
  # covers already-cloned repos instead of only future ones.
  worktreeBootstrapHook = ''
    #!/bin/sh
    # core.hooksPath makes this run for EVERY repository, so it stays
    # conservative and does nothing unless the checkout is certainly new.

    null_sha=0000000000000000000000000000000000000000

    # core.hooksPath replaces .git/hooks wholesale, so always hand control back
    # to a repo-local hook on the way out, or husky-style setups break silently.
    #
    # Resolved via --git-common-dir, NOT `--git-path hooks/post-checkout`: that
    # form honours core.hooksPath and so returns *this* script, which exec'd
    # itself in an infinite loop. The realpath comparison is a second belt for
    # the same hazard, in case a repo points hooksPath back here explicitly.
    chain() {
      common_dir=$(git rev-parse --git-common-dir 2>/dev/null) || exit 0
      hook="$common_dir/hooks/post-checkout"
      if [ -x "$hook" ] \
        && [ "$(readlink -f "$hook")" != "$(readlink -f "$0")" ]
      then
        exec "$hook" "$@"
      fi
      exit 0
    }

    # $1 is the previous HEAD, and only a brand-new checkout has none. A branch
    # switch always passes a real SHA, so this fires exactly once per worktree.
    [ "$1" = "$null_sha" ] && [ "$3" = "1" ] || chain "$@"

    ${lib.optionalString config.code.claude-code.codegraph.enable ''

      # The semantic index describes the code actually checked out here, so each
      # worktree builds its own rather than sharing one. Only for projects already
      # using codegraph — a global hook must not index every repo you clone.
      common=$(git rev-parse --git-common-dir 2>/dev/null) || chain "$@"
      common=$(cd "$common" && pwd)
      main_worktree=$(git worktree list --porcelain | sed -n '1s/^worktree //p')

      if [ ! -d .codegraph ] \
        && [ -d "$main_worktree/.codegraph" ] \
        && command -v codegraph >/dev/null 2>&1
      then
        codegraph init >"$common/codegraph-init-$(basename "$PWD").log" 2>&1 &
      fi
    ''}
    chain "$@"
  '';

  # Authenticates the 21st CLI from sops instead of `21st login`, whose browser
  # flow writes a token to ~/.config on one machine only. This wrapper — not
  # twentyfirst-cli itself — goes on PATH; both provide bin/21st.
  twentyfirstCliWrapper = mkSecretEnvWrapper {
    name = "21st";
    bin = true;
    env.API_KEY_21ST = "services/21st/api-key";
    command = "${twentyfirst-cli}/bin/21st";
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

  # Stop hook: nudge user to run /handoff once the session exceeds
  # `sessionHandoffReminder.thresholdMinutes`. Auto-dismisses once the
  # handoff skill has actually been invoked (detected via a Skill
  # tool_use entry in the transcript). Every error path exits 0 so this can
  # never disrupt Claude.
  sessionHandoffReminderHook = pkgs.writeShellScript "handoff-reminder" ''
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

    # Dismiss the reminder once the handoff skill was actually invoked.
    # Claude Code records skill invocations as a tool_use block with
    # name="Skill" and input.skill="<skill-name>". This is precise — mere
    # discussion of the skill in chat does not match.
    if ${pkgs.jq}/bin/jq -e '.message?.content?[]? | select(.type? == "tool_use" and .name? == "Skill" and .input?.skill? == "handoff")' "$TRANSCRIPT" >/dev/null 2>&1; then
      exit 0
    fi

    HOURS=$((AGE_MIN / 60))
    MINS=$((AGE_MIN % 60))
    # Claude Code's Stop hook discards raw stdout from the user view; the
    # documented way to surface a message in the transcript is JSON with a
    # `systemMessage` field.
    MSG=$(${pkgs.coreutils}/bin/printf '─── Session age: %dh %dm ───\nRun /handoff -> /clear -> Paste context' "$HOURS" "$MINS")
    ${pkgs.jq}/bin/jq -nc --arg msg "$MSG" '{"systemMessage": $msg}'
  '';

  # SessionStart hook: inject the delegation/model-routing policy into Opus
  # sessions only. Fable ships equivalent orchestration guidance natively, and
  # cheaper models are spawn targets, not orchestrators — so the policy is
  # model-gated via this hook instead of a rules file (rules reach every
  # subagent's context; verified empirically, no scoping mechanism exists).
  # Model detection is layered: the documented `model` input field is
  # empirically absent from SessionStart input (docs: "not guaranteed"), so
  # fall back to the parent claude process's --model flag, then the saved
  # /model default (undocumented ~/.claude.json cache slot — best-effort; on
  # a miss the policy is simply not injected, which is harmless).
  delegationPolicy = pkgs.writeText "delegation-policy.md" ''
    # Delegation & Model Routing

    Scope: top-level Opus sessions. A subagent (your first message is a task
    brief from another agent) skips this file: complete the brief directly
    and spawn nothing further.

    You are the orchestrator. Your context window is the scarce resource;
    subagent context is disposable. Plan and synthesize yourself; delegate
    retrieval and bounded execution.

    ## When to spawn
    - The answer is small (paths, a conclusion, yes/no) but reaching it
      means sweeping several files or verbose output → delegate; keep the
      conclusion, not the file dumps.
    - Independent workstreams → spawn all of them in ONE message, in the
      background, and keep working. Continue a live agent via SendMessage
      instead of respawning.
    - Handle it yourself when you know the exact file, when you will Edit
      the file (Edit needs the bytes in your context), when the judgment IS
      the deliverable, or when writing the brief costs more than the task.

    ## Model per spawn — pass `model:` explicitly
    Errors at the top compound; errors at the bottom stay local. Route down
    whatever you can verify cheaply from its answer.
    - haiku: locate / enumerate / fetch — "where is X", "list callers",
      doc lookups
    - sonnet: bounded implementation from a precise spec, summarizing bulk
      material, structured research
    - yourself: planning, review verdicts, synthesis across agent reports,
      anything user-facing

    ## Waiting is free; asking costs a turn
    A spawned agent reports back on its own and the harness notifies you
    when it finishes, so keep working in the meantime. SendMessage and
    ListAgents are for redirecting a live agent, never for asking whether
    one is done. Where you need a condition the harness does not notify
    on, arm Monitor once instead of looping.

    A report that never arrives is still on disk: each subagent's last
    message is captured to
    /tmp/claude-subagent-reports/<session-id>/. Read that file rather than
    re-running the agent.

    ## The brief — a subagent starts with zero context
    State the goal, the scope boundary, the exact return format ("file:line
    + one-line finding"), and what to skip. For Explore, set breadth
    ("medium" or "very thorough"). After spawning: relay findings to the
    user (agent reports are invisible to them) and let delegated work stay
    delegated — verify from the answer, not by redoing the search.
  '';
  delegationPolicyHook = pkgs.writeShellScript "delegation-policy-hook" ''
    INPUT=$(${pkgs.coreutils}/bin/cat)
    # Top-level sessions only: subagents get a task brief, not this policy.
    ${pkgs.jq}/bin/jq -e '.agent_id // empty' >/dev/null <<<"$INPUT" && exit 0

    MODEL=$(${pkgs.jq}/bin/jq -r '.model // empty' <<<"$INPUT")

    # --model flag on the parent claude process (--model X and --model=X).
    if [ -z "$MODEL" ]; then
      MODEL=$(${pkgs.coreutils}/bin/tr '\0' '\n' < /proc/$PPID/cmdline 2>/dev/null | ${pkgs.gawk}/bin/awk '
        /^--model=/ { sub("^--model=",""); print; exit }
        f           { print; exit }
        /^--model$/ { f=1 }')
    fi

    # Saved /model default.
    if [ -z "$MODEL" ]; then
      MODEL=$(${pkgs.jq}/bin/jq -r '[(.clientDataCacheSlots // {}) | .[] | .model? // empty] | first // empty' "$HOME/.claude.json" 2>/dev/null)
    fi

    case "''${MODEL,,}" in
      *opus*) ${pkgs.coreutils}/bin/cat ${delegationPolicy} ;;
    esac
    exit 0
  '';

  # SubagentStop hook: persist each subagent's closing message, so a report
  # that never reaches the orchestrator's context costs one `cat` instead of a
  # re-run. Measured motivation: one review session lost six subagent reports
  # and re-ran those review axes; the delegation policy above names this path
  # so the orchestrator knows where to look.
  #
  # `last_assistant_message` is documented on Stop/SubagentStop input but is
  # NOT verified against a live run here, so the hook degrades instead of
  # assuming: the transcript path is always recorded, and an absent field is
  # written into the file as such rather than producing an empty capture that
  # reads like a silent agent.
  subagentReportCaptureHook = pkgs.writeShellScript "subagent-report-capture" ''
    INPUT=$(${pkgs.coreutils}/bin/cat)
    jq='${pkgs.jq}/bin/jq'

    # Establish parseability first. An input jq cannot read still gets written
    # out verbatim below -- the payload is the whole point of the capture, so
    # a parse failure must not be the one path that loses it.
    if $jq -e . >/dev/null 2>&1 <<<"$INPUT"; then
      session=$($jq -r '.session_id // "unknown-session"' <<<"$INPUT")
      transcript=$($jq -r '.transcript_path // ""' <<<"$INPUT")
      agent=$($jq -r '.agent_name // .agent_type // .agent_id // "subagent"' <<<"$INPUT")
      message=$($jq -r '.last_assistant_message // ""' <<<"$INPUT")
      parsed=1
    else
      session="unparsed"
      transcript=""
      agent="subagent"
      message=""
      parsed=0
    fi
    [ -n "$session" ] || session="unknown-session"
    [ -n "$agent" ] || agent="subagent"

    dir="/tmp/claude-subagent-reports/$session"
    ${pkgs.coreutils}/bin/mkdir -p "$dir"

    # One file per subagent: concurrent writers never share a file, so no
    # locking is owed and a crashed agent leaves a partial file rather than a
    # corrupted shared one.
    stamp=$(${pkgs.coreutils}/bin/date -u +%Y%m%dT%H%M%SZ)
    slug=$(${pkgs.coreutils}/bin/printf '%s' "$agent" | ${pkgs.gnused}/bin/sed 's/[^A-Za-z0-9._-]/-/g')
    [ -n "$slug" ] || slug="subagent"
    out="$dir/$stamp-$slug.md"

    {
      ${pkgs.coreutils}/bin/echo "# subagent report — $agent"
      ${pkgs.coreutils}/bin/echo "captured: $stamp"
      ${pkgs.coreutils}/bin/echo "transcript: ''${transcript:-none in hook input}"
      ${pkgs.coreutils}/bin/echo
      if [ "$parsed" = 0 ]; then
        ${pkgs.coreutils}/bin/echo "Hook input was not valid JSON. Raw payload follows."
        ${pkgs.coreutils}/bin/echo
        ${pkgs.coreutils}/bin/printf '%s\n' "$INPUT"
      elif [ -n "$message" ]; then
        ${pkgs.coreutils}/bin/printf '%s\n' "$message"
      else
        ${pkgs.coreutils}/bin/echo "last_assistant_message was absent from the hook input --"
        ${pkgs.coreutils}/bin/echo "read the transcript above for what this agent returned."
      fi
    } > "$out"

    ${pkgs.coreutils}/bin/echo "subagent report captured: $out"
    exit 0
  '';

  # SessionStart hook: load the local `readable` skill's ruleset from message
  # one, so the output shape applies without typing /readable. The skill is
  # user-invoked (disable-model-invocation), so it costs no context until this
  # hook injects it. READABLE_MODE=off in the environment skips the injection —
  # that is the escape hatch for spawned Hermes workers, whose review ledgers
  # and QA evidence should keep their own format.
  readableHook = pkgs.writeShellScript "readable-session-start" ''
    [ "''${READABLE_MODE:-on}" = "off" ] && exit 0
    ${pkgs.coreutils}/bin/cat ${./skills/readable/SKILL.md}
  '';

  # UserPromptSubmit hook: re-assert the shape once per turn. The SessionStart
  # injection above lands at message one and decays over a long session.
  # Claude Code's built-in output styles solve exactly this with a per-turn
  # `turnReminder` string — a field only built-in styles get, and only one
  # output style can be active at a time, so `readable` cannot be one without
  # displacing the other SessionStart rulesets. This rebuilds the mechanism on
  # the hook we already have; the first sentence is Anthropic's own Concise
  # `turnReminder`, verbatim.
  readableTurnReminderHook = pkgs.writeShellScript "readable-turn-reminder" ''
    [ "''${READABLE_MODE:-on}" = "off" ] && exit 0
    echo "Be concise: lead with the result, skip preamble and narration, keep only what the user needs. Where the response has something to skim, the readable glyphs mark the blocks that carry it."
  '';

  # SessionStart hook: load personal per-project Claude notes, kept as a tracked
  # CLAUDE.k.md instead of the CLAUDE.local.md Claude reads natively.
  #
  # CLAUDE.local.md is gitignored (see programs.git.ignores below), which means
  # it is untracked, unversioned, unreviewable — and, decisively, absent from
  # every new worktree and clone, since git only materialises tracked files.
  # A tracked CLAUDE.k.md rides along everywhere for free; this hook is the
  # naming bridge, and doing it at session start rather than at checkout time
  # is what makes it reach repos cloned before any of this existed.
  #
  # Resolved from the git toplevel, matching Claude's own upward search for
  # memory files, and correct per-worktree (each has its own toplevel).
  projectNotesHook = pkgs.writeShellScript "claude-project-notes" ''
    root=$(${pkgs.git}/bin/git rev-parse --show-toplevel 2>/dev/null) || exit 0
    [ -f "$root/CLAUDE.k.md" ] && ${pkgs.coreutils}/bin/cat "$root/CLAUDE.k.md"
    exit 0
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

  # home-manager renders ~/.claude/settings.json as a /nix/store symlink, so
  # every runtime write Claude makes to it (/effort, /model, theme, …) dies
  # with EROFS. Install a real writable file instead — same content, but a
  # copy. Nix stays authoritative: each activation overwrites it, so the
  # declared values are the defaults and runtime tweaks last until the next
  # `nh os switch`.
  claudeSettingsFile =
    (pkgs.formats.json {}).generate "claude-code-settings.json"
    (config.programs.claude-code.settings
      // {
        "$schema" = "https://json.schemastore.org/claude-code-settings.json";
      });
  claudeSettingsInstall = pkgs.writeShellScript "claude-settings-install" ''
    dst="$HOME/.claude/settings.json"
    ${pkgs.coreutils}/bin/mkdir -p "$HOME/.claude"
    ${pkgs.coreutils}/bin/rm -f "$dst"
    ${pkgs.coreutils}/bin/install -m 0644 ${claudeSettingsFile} "$dst"
  '';

  # claude-mem's vector search shells out to `uvx chroma-mcp`. uv fetches
  # python-build-standalone plus manylinux wheels, and NumPy's wheel dlopen's
  # libstdc++.so.6 at import time — which nothing on NixOS puts in that
  # process's search path, so chroma-mcp dies with
  # "libstdc++.so.6: cannot open shared object file" and the worker reports
  # "Dependencies: degraded (uvx unavailable for vector search)".
  #
  # nix-ld (nixosModules/system/utils.nix) does not help here: it rewrites the
  # interpreter for the binary it launches, but the failing load is a dlopen
  # from inside uv's own Python, which only consults LD_LIBRARY_PATH.
  #
  # Setting LD_LIBRARY_PATH globally would leak into every process on the
  # system, so scope it to exactly this call instead: claude-mem takes a
  # `CLAUDE_MEM_CHROMA_UVX_PATH` override for the uvx it invokes, so point that
  # at a wrapper (wired up in `settings.env` below — it is read from
  # process.env, not from ~/.claude-mem/settings.json). Verified 2026-08-26:
  # `uvx chroma-mcp --help` succeeds through the wrapper in 2 s and the worker's
  # "degraded" line disappears.
  claudeMemUvx = pkgs.writeShellScriptBin "uvx" ''
    export LD_LIBRARY_PATH="${lib.makeLibraryPath [pkgs.stdenv.cc.cc.lib pkgs.zlib]}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    exec ${pkgs.uv}/bin/uvx "$@"
  '';

  claudeMemSettingsFile =
    (pkgs.formats.json {}).generate "claude-mem-managed-settings.json"
    config.code.claude-code.claude-mem.settings;

  # Merge rather than replace — see the `claude-mem.settings` option for why the
  # file cannot be a store symlink.
  claudeMemSettingsInstall = pkgs.writeShellScript "claude-mem-settings-install" ''
    set -eu
    dir="$HOME/.claude-mem"
    dst="$dir/settings.json"
    ${pkgs.coreutils}/bin/mkdir -p "$dir"
    [ -f "$dst" ] || ${pkgs.coreutils}/bin/printf '{}\n' > "$dst"

    tmp="$(${pkgs.coreutils}/bin/mktemp "$dir/.settings.json.XXXXXX")"
    ${pkgs.jq}/bin/jq -S -s '.[0] * .[1]' "$dst" ${claudeMemSettingsFile} > "$tmp"

    if ${pkgs.jq}/bin/jq -S . "$dst" | ${pkgs.diffutils}/bin/cmp -s - "$tmp"; then
      ${pkgs.coreutils}/bin/rm -f "$tmp"
      exit 0
    fi

    ${pkgs.coreutils}/bin/mv -f "$tmp" "$dst"
    ${pkgs.coreutils}/bin/chmod 0644 "$dst"
    echo "claude-mem: settings.json updated"

    # The worker caches settings at start, so a changed file only takes effect
    # once it goes down. Path is version-scoped and mutable (the marketplace
    # clone), so resolve the newest one at runtime rather than pinning it.
    scripts=""
    for c in "$HOME"/.claude/plugins/cache/thedotmack/claude-mem/*/scripts; do
      # An unmatched glob stays literal, so the -f test is what filters it —
      # keep it inside an `if` so a false test can't trip `set -e`.
      if [ -f "$c/worker-service.cjs" ] && [ -f "$c/bun-runner.js" ]; then scripts="$c"; fi
    done
    if [ -n "$scripts" ]; then
      echo "claude-mem: stopping worker so it reloads (next session restarts it)"
      # Must go through bun-runner: worker-service.cjs uses bun-only APIs and
      # crashes when handed straight to node.
      ${pkgs.nodejs}/bin/node "$scripts/bun-runner.js" "$scripts/worker-service.cjs" stop >/dev/null 2>&1 || true
    fi
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
    shadcn.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the `shadcn` CLI (from pkgs-unstable) plus the custom `shadcn-index` wrapper. shadcn's built-in registry directory covers ~237 third-party registries (@magicui, @aceternity, @cult-ui, @react-bits, …), and `shadcn view @ns/item` prints an item's full source with no API key, no project and no quota — the cheapest way for an agent to read a component's real API before writing against it. shadcn has no global search (`search` takes a namespace), so `shadcn-index <query>` searches a curated trust-list of high-craft registries at once (`--all` widens to the whole directory, `--json` for agents).";
    };
    twentyfirst.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the 21st.dev CLI (`21st`) plus its three upstream skills (21st-cli-use, 21st-registry, 21st-design-sync): search/install React + shadcn components, themes and templates, and publish your own. Chosen over 21st's MCP server, which would cost tool-schema tokens on every turn. Reads API_KEY_21ST from sops services/21st/api-key, so no per-machine `21st login`.";
    };
    higgsfield.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the Higgsfield AI CLI (`higgsfield`/`higgs`/`hf`): generate images and videos from the terminal. Packages the prebuilt `hf` binary from the GitHub release (the npm package is only a downloader). Auth is interactive — run `higgsfield auth login` once per machine.";
    };
    marketing-skills.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the coreyhaines31/marketingskills plugin (marketing-skills@marketingskills): 47 marketing skills for founders and technical marketers — CRO, copywriting, cold email, SEO/AI-SEO, paid ads, ad creative, pricing, referrals, revops, customer research, AARRR marketing plans, and more. Default-off after the 2026-08-26 audit: one lifetime invocation in 451 startups, and its 50 broadly-worded trigger descriptions (schema, image, video, analytics) compete for the capped skill-listing budget against skills that are actually used.";
    };
    printing-press.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the cli-printing-press Claude Code plugin (marketplace + generator skills) and the Go toolchain it needs.";
    };
    playground.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the Anthropic-verified playground plugin (playground@claude-plugins-official): /playground generates self-contained interactive HTML playgrounds (design, data explorer, concept map, document critique, diff review, code map) with live preview and copyable prompt output. Default-off after the 2026-08-26 audit: 4 lifetime invocations, last 2026-06-15, and visual-explainer covers the same ground.";
    };

    skill-creator.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the Anthropic-verified skill-creator plugin (skill-creator@claude-plugins-official): scaffolds new skills, edits existing ones, and runs eval/benchmark suites against a skill's description to measure triggering accuracy. Default-off after the 2026-08-26 audit: 1 lifetime invocation in 451 startups, while skill authoring in practice goes through the local `writing-for-agents` skill. Re-enable if you start iterating on skill descriptions with its eval harness rather than by hand.";
    };

    obsidian.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the kepano/obsidian-skills plugin (obsidian@obsidian-skills): obsidian-cli, obsidian-markdown, obsidian-bases, json-canvas, and `defuddle` (strips a web page to clean markdown). Default-off after the 2026-08-26 audit: zero invocations across 387 startups since install. `defuddle` is the one piece with a live use case (it should be replacing WebFetch on article/doc pages) — re-enable together with a rule that names it, or the plugin sits idle again.";
    };

    gsd.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Link the gsd-build/get-shit-done workflow into ~/.claude: 67 `/gsd:*` commands and 33 `gsd-*` subagents implementing a full `.planning/`-directory methodology (roadmap → spec → discuss → plan → execute → verify). Default-off after the 2026-08-26 audit: the 33 agent definitions cost a measured 3,645 tokens of startup context every session (agent listings, unlike skill listings, are not budget-capped) against zero agent spawns ever and one `/gsd:help` invocation on 2026-05-08. Commands and agents are gated together because the commands dispatch to the agents — shipping one without the other only produces broken slash commands.";
    };
    visual-explainer.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable the nicobailon/visual-explainer plugin: slash commands (/generate-web-diagram, /generate-slides, /diff-review, /plan-review, etc.) that produce standalone HTML pages for diagrams, diff/plan reviews, slides, and data tables.";
    };
    ponytail = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Enable the DietrichGebert/ponytail plugin: an always-on "laziest senior dev" ruleset that steers code generation toward the minimum the task needs (YAGNI, reuse, native/stdlib features, one-liners) without cutting validation, security, or accessibility. Adds /ponytail (set intensity), /ponytail-review (diff over-engineering delete-list), /ponytail-audit (repo-wide bloat), /ponytail-debt (deferred-shortcut ledger), /ponytail-gain, /ponytail-help. Two tiny Node lifecycle hooks drive the always-on activation — `node` is already on PATH via home.packages. Intensity is set per-session by `defaultMode` below (PONYTAIL_DEFAULT_MODE).
        '';
      };
      defaultMode = lib.mkOption {
        type = lib.types.enum ["lite" "full" "ultra" "off"];
        default = "full";
        description = ''
          Ponytail intensity for every new session, exported as PONYTAIL_DEFAULT_MODE. Matches upstream's default ("full") — applies the laziness ladder on every coding turn. "lite" trims the every-turn context cost of the injected ruleset, "ultra" is the maximal-pushback mode, "off" disables the always-on injection (the /ponytail commands still work). Override per-session at runtime with `/ponytail lite|full|ultra|off`.
        '';
      };
    };
    readable.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Load the local `readable` skill (skills/readable/) from message one via a SessionStart hook: bottom line first, eight line-leading role markers (recommendation, question, done, failed, risk, blocked, assumption, tangent), tangents deferred to the end at full length, and every claim paired with its check. A fork of ayghri/i-have-adhd with the omission-prone rules removed — no list cap, no step trimming, no time estimates — and scoped to conversational output so reports, PR comments, commit messages and machine-readable markers keep their own formats. Absorbs the wording of Claude Code's built-in Concise output style (cut narration, short by default, state things plainly, correctness never traded for brevity) rather than enabling it, since only one output style can be active and its "these rules win" clause would otherwise override the marker layer; a paired UserPromptSubmit hook replays Concise's per-turn `turnReminder` line, which built-in styles get and hooks otherwise do not. Turn off for one session with "stop readable", or per-process with READABLE_MODE=off (used for spawned Hermes workers that produce review ledgers and QA evidence) — the env gate covers both hooks.
      '';
    };
    projectNotes.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Read a project's CLAUDE.k.md into context at session start. Personal per-project Claude notes kept under version control: unlike the CLAUDE.local.md Claude loads natively, a tracked file is reviewable, survives a reclone, and arrives in every new worktree without any bootstrap step. Resolved from the git toplevel, so it works from any subdirectory and picks up each worktree's own copy.";
    };
    codex.enable = lib.mkOption {
      type = lib.types.bool;
      default = config.code.codex.enable;
      description = ''
        Enable the openai/codex-plugin-cc plugin for Claude Code (slash commands /codex:setup, /codex:review, /codex:status, /codex:result and the codex:codex-rescue subagent). The plugin shells out to the local Codex CLI; defaults to whatever `code.codex.enable` is set to so the binary is present.
      '';
    };
    claude-mem = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Enable the thedotmack/claude-mem plugin: persistent memory across Claude Code sessions. Captures tool-use observations, compresses them with an AI provider, and re-injects relevant context on session start. Hooks and worker live entirely under ~/.claude/plugins/marketplaces/thedotmack/ (mutable, not nix-managed), so it coexists with the nix-rendered settings.json. Requires `node` (already provided) and an AI provider configured at runtime — see https://docs.claude-mem.ai.
        '';
      };

      settings = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {
          # 2026-08-26 audit. The three knobs that decide what claude-mem costs:
          #
          # SKIP_TOOLS  — the PostToolUse hook is registered with matcher "*"
          #   inside the plugin's own hooks.json, which we cannot patch (it is a
          #   mutable marketplace clone that `claude plugin update` overwrites
          #   nightly). The worker filters internally instead:
          #   worker-service.cjs / transcript-watcher.cjs both do
          #   `if (SKIP_TOOLS.has(t.toolName)) return {status:"skipped"}`.
          #   Adding Read/Grep/Glob to upstream's list drops the observation
          #   pass — and its Haiku call — for the tool calls that generated 34%
          #   of the 10,878-row database while writing back nothing actionable.
          #   The hook still fires (~361 ms/call); what this saves is API spend
          #   and database growth, not hook latency.
          #
          # CONTEXT_OBSERVATIONS / CONTEXT_SESSION_COUNT — the SessionStart
          #   digest measured 2,938 tokens, split 1,474 (50 observation lines) /
          #   1,359 (10 session-summary blocks) / 104 header. It is not a fixed
          #   cost: it grew ~870 tokens mid-audit when that session's own
          #   summary landed. Both counts scale roughly linearly, so 20/5 caps
          #   the digest near ~1,500 tokens instead of letting it drift upward.
          CLAUDE_MEM_SKIP_TOOLS = "ListMcpResourcesTool,SlashCommand,Skill,TodoWrite,AskUserQuestion,Read,Grep,Glob";
          CLAUDE_MEM_CONTEXT_OBSERVATIONS = "20";
          CLAUDE_MEM_CONTEXT_SESSION_COUNT = "5";

          # Declared rather than left implicit: semantic recall is the only read
          # path claude-mem has that anyone would use, and it had never once
          # worked on this machine before `claudeMemUvx` (above) fixed the
          # chroma-mcp launch. Turning it off makes `mem-search` pointless;
          # leaving it on without the wrapper just logs "degraded" forever.
          CLAUDE_MEM_CHROMA_ENABLED = "true";
        };
        description = ''
          Keys to enforce in ~/.claude-mem/settings.json on every activation.

          That file cannot be a /nix/store symlink: claude-mem owns it (70+ keys,
          including provider credentials it writes itself via `updateSettings`),
          and a read-only symlink would break both its own writes and any key a
          future version adds. So activation merges these keys into whatever is
          on disk — declared keys win, every other key is left untouched — and
          stops the worker when the merge actually changes something, since the
          worker reads settings once at start. The next session's SessionStart
          hook brings it back up.

          Only applied when `claude-mem.enable` is true.
        '';
      };
    };
    tokenOptimizer.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable the alexgreensh/token-optimizer plugin: monthly-cadence context audits and health reports. Provides slash commands /token-optimizer, /coach, /memory-review, /attention-score, /drift, /triage, /doctor, /quality, /report, /savings, /jsonl-inspect. Layer A only — marketplace registration + plugin enablement. Deliberately does NOT run the upstream setup-hook/setup-smart-compact/setup-daemon/setup-quality-bar scripts, which would mutate ~/.claude/settings.json (a /nix/store symlink). One-shot dashboard via `python3 measure.py dashboard --serve` when needed. License: PolyForm Noncommercial — personal use only.
      '';
    };
    superpowers.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the superpowers@claude-plugins-official plugin: a meta-skill framework (brainstorming, TDD, systematic-debugging, writing-skills, etc.) that injects skill-discovery instructions at session start.";
    };
    rtk.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable RTK (rtk-ai/rtk): CLI proxy + Claude Code PreToolUse hook that rewrites common dev commands (git/cat/grep/test runners) to compact RTK equivalents for 60-90% token savings on Bash tool calls. Measure with `rtk gain` after a few sessions.";
    };
    codeburn.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Install codeburn (getagentseal/codeburn): AI coding token usage tracker with a `codeburn web` dashboard.";
    };
    sessionHandoffReminder = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Print a reminder after every Claude turn once the session exceeds thresholdMinutes, suggesting /handoff then /clear. Auto-dismisses once the session-handoff skill has produced its template this session.";
      };
      thresholdMinutes = lib.mkOption {
        type = lib.types.int;
        default = 60;
        description = "Minutes of session age before the reminder starts firing.";
      };
    };
    delegationPolicy.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Inject a subagent delegation + model-routing policy at session start, gated to Opus sessions only (SessionStart hook detects the model via hook input, the parent process's --model flag, or the saved /model default). Teaches Opus to orchestrate like Fable: fan out retrieval to haiku, bounded work to sonnet, keep judgment at the top. Fable sessions, cheaper models, and subagents never see it. Also wires a SubagentStop hook that persists each subagent's closing message to /tmp/claude-subagent-reports/<session-id>/, one file per agent, so a report lost on the way back costs a `cat` instead of a re-run — the policy text names that path, so the two travel together.";
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
      # Pre-wrapped with `--mcp-config=<file>` so `claude plugin|mcp|doctor …`
      # stop erroring on the flag — see claudeCodeWrapped above.
      package = claudeCodeWrapped;

      # Skills (managed via skills, see ./skills/)
      skills = ./skills;

      # Global behavioral guidelines (Karpathy-inspired) → ~/.claude/CLAUDE.md
      context = ''
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

        ## 5. Evaluate My Ideas on Merit

        **My suggestions are hypotheses, not instructions. Agreement has to be earned.**

        When I propose an idea, diagnosis, or approach:
        - Judge it against the code and the facts — not against how confident I sounded.
        - If it's wrong, lead with the flaw. No "great idea, but". State the problem, then the alternative.
        - If it's right, one line saying so. No praise, no replaying my reasoning back at me.
        - If it's right but something else is better, give both and recommend one.
        - Verify before agreeing. "That's a good point" without checking the code is a guess wearing a compliment.

        Don't manufacture disagreement either. Contrarianism is the same failure as flattery: a posture substituted for an evaluation.

        If I push back on your objection: update if I gave you a new fact or constraint. If I only restated my position, say you still disagree and why — then do it my way if I insist, without pretending I convinced you.

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

          browser = ''
            # Browser Control

            Drive browsers with the `agent-browser` CLI, in preference to the
            Claude Chrome extension — it launches its own browser, so nothing
            waits on me to open a window first.

            When a task needs a browser, work down this ladder:

            1. `agent-browser` — the default.
            2. The Claude Chrome extension (`mcp__claude-in-chrome__*`) — only
               when `agent-browser` is absent or refuses to launch.
            3. Neither drives a page → say so plainly and stop. Report only
               what you actually observed in a browser; curl proves a status
               code, never a rendered page.

            ```sh
            [ -n "$WAYLAND_DISPLAY$DISPLAY" ] && HEADED=--headed
            agent-browser open <url> $HEADED
            agent-browser snapshot -i   # interactive elements as @e1, @e2 refs
            agent-browser click @e1     # re-snapshot after the page changes
            agent-browser console       # devtools console errors
            ```

            Pass `--headed` whenever a display exists so I can watch the run;
            omit it on headless hosts.

            `agent-browser install` is the one command to skip: the
            Chrome-for-Testing build it downloads cannot start on NixOS. The
            package already defaults `AGENT_BROWSER_EXECUTABLE_PATH` to nixpkgs
            chromium, so `open` needs no setup.
          '';

          interview-style = ''
            # Interview / Grilling Style

            During grilling, grill-me, grill-with-docs, or any
            interview-style session where you question me about a plan or
            design, ask questions as plain free-text prose — one at a
            time, each with your recommended answer stated. Do NOT use the
            AskUserQuestion multiple-choice tool for these; I want to
            answer in my own words so I can be nuanced.

            This applies only to interview/grilling sessions — keep using
            multiple-choice freely for quick config or routing decisions
            elsewhere.
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
          # This rule carried "CodeGraph does not parse Nix" until 2026-08-26,
          # which was false and kept the tool out of this repo — the one we work
          # in most. codegraph 1.5.0 ships tree-sitter-nix plus a nix extractor
          # (attrsets, bindings, let, function expressions, inherit, import);
          # indexing this repo produced 7,300 nodes from 302 files in 589 ms.
          # The trigger is behavioural rather than "if a .codegraph/ dir exists"
          # for the same reason: the passive form measured zero pickup across
          # every session on record, including in fully indexed JS/TS projects
          # where 500+ grep-like calls ran instead.
          codegraph = ''
            # CodeGraph (Semantic Code Intelligence)

            Reach for CodeGraph before the second grep of the same
            investigation. One call returns the relevant symbols' verbatim
            line-numbered source grouped by file, the call paths between them,
            and a blast-radius summary — including dynamic-dispatch hops
            (callbacks, interface→impl) grep cannot follow.

            The MCP surface is a single tool, `mcp__codegraph__codegraph_explore`.
            It answers "how does X work", a flow ("how does X reach Y"), or a
            survey of an area; naming a file or symbol in the query reads its
            current source. Query another indexed project — a sibling repo, or a
            service inside a monorepo — by passing `projectPath`.

            Subagents and non-MCP harnesses have no MCP tools, so they use the
            identical CLI instead: `codegraph explore <query>`. Also on the CLI
            only: `codegraph node|query|callers|callees|impact|files|status`
            (the same operations exist as MCP tools but are unlisted by default;
            `CODEGRAPH_MCP_TOOLS=explore,node,search,...` re-lists them).

            An unindexed project returns guidance to use the built-in tools
            rather than failing — indexing stays a deliberate choice. To make
            one: `codegraph init` in its root, which builds the graph in the
            same step. From then on the MCP server watches the tree and syncs
            on every change, and reconciles against disk when it reconnects, so
            the index is never stale and there is nothing to re-run.

            Nix is supported, so this repo is a valid target too.
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

      # MCP servers live in the `claudeMcpServers` let-binding at the top of
      # this file and reach `claude` through `claudeCodeWrapped`, not through
      # this option — see the comment there for why.

      # Additional settings
      settings = {
        showThinkingSummaries = true;
        cleanupPeriodDays = 14;
        tui = "default"; # opt out of fullscreen renderer + its startup prompt
        effortLevel = "high"; # default reasoning effort; /effort overrides per-session
        includeCoAuthoredBy = false;
        skipDangerousModePermissionPrompt = true;

        # System-prompt bloat trimming (see aihero.dev "How To Kill The Bloat
        # In Claude Code's System Prompt"). Each flag drops a whole feature —
        # its tools + instructions — from the per-turn payload:
        # - Workflows: unused; well-defined agent teams (CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS) cover it.
        # - RemoteControl: work is driven via Discord/Hermes, not CC's remote-control feature.
        # - ClaudeAiConnectors: Gmail/Calendar/Drive handled via CLIs instead.
        # - Artifact: our HTML skills (visual-explainer/storm/playground/impeccable) Write local files, not claude.ai Artifacts.
        # Individual-tool trims live in permissions.deny below (bare names strip the schema).
        # Deliberately NOT set: disableBundledSkills (would hide /code-review + /security-review
        # from the review-gate team; use skillOverrides per-skill if ever needed).
        disableWorkflows = true;
        disableRemoteControl = true;
        disableClaudeAiConnectors = true;
        disableArtifact = true;

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
            # Wildcard, not a name list: as of 1.5.0 the server lists exactly one
            # tool (codegraph_explore) and keeps the older narrow ones callable
            # but unlisted, so any hand-written list goes stale the moment that
            # surface moves — which it already had.
            ++ lib.optionals config.code.claude-code.codegraph.enable [
              "mcp__codegraph__*"
            ];
          deny = [
            "Bash(sops:*)"
            "Bash(age:*)"
            "Read(/run/secrets/**)"
            "Read(/run/secrets.d/**)"
            "Read(/home/hailst0rm/.config/sops/**)"
            "Read(/home/hailst0rm/.config/sops-nix/**)"

            # Payload trimming: bare tool names strip the tool's schema from the
            # per-turn request (a scoped rule would only block calls, not shrink
            # the payload). Cut features we don't use on this setup:
            # - EnterPlanMode/ExitPlanMode: wayfinder/grilling plan as a method, not CC plan mode.
            # - AskUserQuestion: removing it keeps clarifying questions but forces
            #   free-text prose (matches interview-style), same question frequency.
            # - NotebookEdit: no Jupyter here. DesignSync: unused.
            # - Push/RemoteTrigger: driven via Discord/Hermes. Cron*: scheduled via Hermes cron.
            # - ScheduleWakeup: only used by /loop dynamic mode, unused.
            # Kept ON PURPOSE: SendMessage (agent-team channel), ReportFindings
            # (/code-review + /security-review emit through it in the review gate).
            "EnterPlanMode"
            "ExitPlanMode"
            "DesignSync"
            "NotebookEdit"
            "PushNotification"
            "RemoteTrigger"
            "ScheduleWakeup"
            "AskUserQuestion"
            "CronCreate"
            "CronDelete"
            "CronList"
          ];
        };

        env =
          {
            CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR = "1";
            CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
          }
          // lib.optionalAttrs config.code.claude-code.claude-mem.enable {
            # Has to be an env var, not a settings.json key: claude-mem reads it
            # straight off process.env, and its uvx search list is only
            # [override, ~/.local/bin, ~/.cargo/bin, …] — it never consults PATH,
            # so the uvx in /etc/profiles/per-user is invisible to it. The
            # worker is always started by claude-mem's own SessionStart hook,
            # which inherits this. See `claudeMemUvx` for what the wrapper fixes.
            CLAUDE_MEM_CHROMA_UVX_PATH = "${claudeMemUvx}/bin/uvx";
          }
          // lib.optionalAttrs config.code.claude-code.ponytail.enable {
            # Ponytail intensity for every new session (lite/full/ultra/off).
            PONYTAIL_DEFAULT_MODE = config.code.claude-code.ponytail.defaultMode;
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
        # - SessionStart (delegation policy): Opus-only orchestration/model-routing context.
        # - SubagentStop (delegation policy): persists each subagent's closing message.
        # - SessionStart (readable): loads the output-shape ruleset from message one.
        # - UserPromptSubmit (readable): one-line per-turn reminder against drift.
        # - SessionStart (project notes): reads the repo's tracked CLAUDE.k.md.
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
          (lib.mkIf config.code.claude-code.delegationPolicy.enable {
            SessionStart = [
              {
                hooks = [
                  {
                    type = "command";
                    command = "${delegationPolicyHook}";
                  }
                ];
              }
            ];
            SubagentStop = [
              {
                hooks = [
                  {
                    type = "command";
                    command = "${subagentReportCaptureHook}";
                  }
                ];
              }
            ];
          })
          (lib.mkIf config.code.claude-code.readable.enable {
            SessionStart = [
              {
                hooks = [
                  {
                    type = "command";
                    command = "${readableHook}";
                  }
                ];
              }
            ];
            UserPromptSubmit = [
              {
                hooks = [
                  {
                    type = "command";
                    command = "${readableTurnReminderHook}";
                  }
                ];
              }
            ];
          })
          (lib.mkIf config.code.claude-code.projectNotes.enable {
            SessionStart = [
              {
                hooks = [
                  {
                    type = "command";
                    command = "${projectNotesHook}";
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
            # "frontend-design@claude-plugins-official" = true;  # Replaced by impeccable (strict superset)
            "impeccable@impeccable" = true;
            "context-mode@context-mode" = true;
          }
          // lib.optionalAttrs config.code.claude-code.skill-creator.enable {
            "skill-creator@claude-plugins-official" = true;
          }
          // lib.optionalAttrs config.code.claude-code.obsidian.enable {
            "obsidian@obsidian-skills" = true;
          }
          // lib.optionalAttrs config.code.claude-code.marketing-skills.enable {
            "marketing-skills@marketingskills" = true;
          }
          // lib.optionalAttrs config.code.claude-code.superpowers.enable {
            "superpowers@claude-plugins-official" = true;
          }
          // lib.optionalAttrs config.code.claude-code.playground.enable {
            "playground@claude-plugins-official" = true;
          }
          // lib.optionalAttrs config.code.claude-code.visual-explainer.enable {
            "visual-explainer@visual-explainer-marketplace" = true;
          }
          // lib.optionalAttrs config.code.claude-code.ponytail.enable {
            "ponytail@ponytail" = true;
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
          // lib.optionalAttrs config.code.claude-code.obsidian.enable {
            obsidian-skills = {
              source = {
                source = "github";
                repo = "kepano/obsidian-skills";
              };
            };
          }
          // lib.optionalAttrs config.code.claude-code.marketing-skills.enable {
            marketingskills = {
              source = {
                source = "github";
                repo = "coreyhaines31/marketingskills";
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
          // lib.optionalAttrs config.code.claude-code.ponytail.enable {
            ponytail = {
              source = {
                source = "github";
                repo = "DietrichGebert/ponytail";
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

    # GSD (Get Shit Done) commands and agents, gated on `gsd.enable` +
    # Matt Pocock skills (flat-linked from upstream plugin.json, plus the
    # mattpocockExtraSkills opt-ins above)
    home.file =
      {
        # Rendered as a mutable copy by claudeSettingsInstall instead, so
        # Claude can write /effort, /model & co. back into it at runtime.
        ".claude/settings.json".enable = false;
        # home-manager's native programs.claude-code module (settings != {})
        # writes this same file under its own key, built from an absolute
        # path — a different attribute name than the relative key above, so
        # it isn't covered by the disable and fights claudeSettingsInstall.
        "${config.home.homeDirectory}/.claude/settings.json".enable = false;

        # Upstream ships a discovery stub (`hidden: true`) that pulls the real
        # workflow content from the CLI at use time — `agent-browser skills get
        # core`, backed by $out/skill-data. Both land via pkgs/agent-browser.
        # The always-on browser rule stays as-is; it carries the NixOS specifics
        # (no `agent-browser install`, chromium default, --headed) the stub can't know.
        ".claude/skills/agent-browser".source = "${pkgs.agent-browser}/skills/agent-browser";

        # The excalidraw-diagram skill's renderer serves this bundle over a
        # throwaway localhost server and drives it with agent-browser, so
        # rendering needs no network and no playwright (whose binary wheels and
        # downloaded chromium both fail to load on NixOS).
        ".claude/skills/excalidraw-diagram/references/excalidraw-utils.js".source = excalidrawUtils;
      }
      // lib.optionalAttrs config.code.claude-code.gsd.enable {
        ".claude/commands/gsd".source = "${gsd-repo}/commands/gsd";
        ".claude/agents" = {
          source = "${gsd-repo}/agents";
          recursive = true;
        };
      }
      // mattpocockSkillFiles
      // twentyfirstSkillFiles
      // lib.optionalAttrs config.importConfig.git.enable {
        ".config/git/hooks/post-checkout" = {
          executable = true;
          text = worktreeBootstrapHook;
        };
      };

    # Runs after linkGeneration so the previous generation's settings.json
    # symlink is already gone when we drop the real file in its place.
    home.activation.claudeSettings = lib.hm.dag.entryAfter ["linkGeneration"] ''
      run ${claudeSettingsInstall}
    '';

    home.activation.claudeMemSettings =
      lib.mkIf config.code.claude-code.claude-mem.enable
      (lib.hm.dag.entryAfter ["linkGeneration"] ''
        run ${claudeMemSettingsInstall}
      '');

    # Machine-local tooling output that no repo should ever track. Global
    # rather than per-repo .gitignore: these are our tools, not the projects',
    # so they must not land in a shared repo's ignore file.
    programs.git = lib.mkIf config.importConfig.git.enable {
      settings.core.hooksPath = "${config.home.homeDirectory}/.config/git/hooks";
      ignores =
        [
          "CLAUDE.local.md"
          "**/.claude/settings.local.json"
        ]
        ++ lib.optional config.code.claude-code.codegraph.enable ".codegraph/";
    };

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

        # Browser automation CLI for agents — `/qa-plan` drives it over CDP.
        # Built from pkgs/agent-browser/package.nix.
        agent-browser
      ]
      ++ lib.optionals config.code.claude-code.codeburn.enable [
        codeburn # AI coding token usage tracker
      ]
      ++ lib.optionals config.code.claude-code.sound.enable [
        sound-theme-freedesktop # complete.oga / bell.oga for Claude Code Stop + Notification hooks
      ]
      ++ lib.optionals config.code.claude-code.printing-press.enable [
        go # /printing-press generator shells out to `go install`/`go build`
      ]
      ++ lib.optionals config.code.claude-code.rtk.enable [
        rtk # Token-compact CLI proxy invoked by rtkRewriteHook + meta-commands (`rtk gain`, etc.). From nixpkgs-unstable.
      ]
      ++ lib.optionals config.code.claude-code.claude-mem.enable [
        bun # claude-mem's hooks shell out to `bun` via scripts/bun-runner.js
      ]
      ++ lib.optionals config.code.claude-code.codegraph.enable [
        codegraphCliWrapper # `codegraph` CLI for `codegraph init`/`init --index` in project roots
      ]
      ++ lib.optionals config.code.claude-code.twentyfirst.enable [
        twentyfirstCliWrapper # `21st` CLI driven by the 21st-* skills, with API_KEY_21ST from sops. Built from pkgs/21st-cli/package.nix.
      ]
      ++ lib.optionals config.code.claude-code.shadcn.enable [
        pkgs-unstable.shadcn # `shadcn search @ns -q`/`view @ns/item`/`add` over the built-in registry directory.
        shadcn-index # `shadcn-index <query>` — global keyword search shadcn itself refuses; built from pkgs/shadcn-index/package.nix.
      ]
      ++ lib.optionals config.code.claude-code.higgsfield.enable [
        higgsfield-cli # `higgsfield`/`higgs`/`hf` — Higgsfield AI image/video CLI. Built from pkgs/higgsfield-cli/package.nix.
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
