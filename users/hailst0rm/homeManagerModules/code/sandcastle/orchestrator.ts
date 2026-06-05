/**
 * Sandcastle autonomous pipeline — orchestrator (Phase 1: logic chain).
 *
 * Runs OUTSIDE the sandbox, on the host. Drives Claude Code agents through a
 * fixed skill chain inside an isolated per-issue git worktree (container:
 * podman or docker), processing several `ready-for-agent` GitHub issues with
 * bounded concurrency, and opens a PR per issue WITHOUT closing it
 * (/qa-plan relabels the issue `ready-for-human`). Merges are handled manually.
 *
 * It is fully parameterised by environment variables so the nix wrapper owns
 * every host/store path and secret; this file stays generic.
 *
 *   Required env (injected by the `sandcastle-run` nix wrapper):
 *     CLAUDE_CODE_OAUTH_TOKEN  subscription headless auth (sops)
 *     GH_TOKEN                 fine-grained, repo-scoped GitHub PAT (sops)
 *     SANDCASTLE_IMAGE         podman image name (e.g. "sandcastle-agent:latest")
 *     SANDCASTLE_CLAUDE_DIR    host ~/.claude (skills/plugins/agents live here)
 *     SANDCASTLE_SETTINGS      host path to the sandbox-specific settings.json
 *   Optional env:
 *     SANDCASTLE_CODEX_AUTH    host ~/.codex/auth.json (enables /codex:review)
 *     SANDCASTLE_MODEL         default "claude-opus-4-7"
 *     SANDCASTLE_EFFORT        default "high"
 *     SANDCASTLE_BASE_BRANCH   default "master"
 *     SANDCASTLE_LABEL         default "ready-for-agent"
 *     SANDCASTLE_MAX_ISSUES    default "4" (max issues processed per invocation)
 *     SANDCASTLE_CONCURRENCY   default "2" (max issues worked in parallel)
 *     SANDCASTLE_IMPLEMENT_ITERATIONS default "40" (tdd step re-invocation cap)
 *     SANDCASTLE_CONTAINER     "podman" (default) | "docker"
 *     SANDCASTLE_DRY_RUN       "1" → list what would run, do nothing
 *
 *   Usage:  sandcastle-run <path-to-project-repo>
 */
import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { createSandbox, claudeCode } from "@ai-hero/sandcastle";
import { podman } from "@ai-hero/sandcastle/sandboxes/podman";
import { docker } from "@ai-hero/sandcastle/sandboxes/docker";

const COMPLETE = "<promise>COMPLETE</promise>";

function env(name: string, fallback?: string): string {
  const v = process.env[name] ?? fallback;
  if (v === undefined) throw new Error(`Missing required env: ${name}`);
  return v;
}

const cfg = {
  image: env("SANDCASTLE_IMAGE"),
  claudeDir: env("SANDCASTLE_CLAUDE_DIR"),
  settings: env("SANDCASTLE_SETTINGS"),
  codexAuth: process.env.SANDCASTLE_CODEX_AUTH,
  model: env("SANDCASTLE_MODEL", "claude-opus-4-7"),
  effort: env("SANDCASTLE_EFFORT", "high") as
    | "low"
    | "medium"
    | "high"
    | "xhigh"
    | "max",
  baseBranch: env("SANDCASTLE_BASE_BRANCH", "master"),
  label: env("SANDCASTLE_LABEL", "ready-for-agent"),
  maxIssues: parseInt(env("SANDCASTLE_MAX_ISSUES", "4"), 10),
  concurrency: parseInt(env("SANDCASTLE_CONCURRENCY", "2"), 10),
  implementIterations: parseInt(env("SANDCASTLE_IMPLEMENT_ITERATIONS", "40"), 10),
  container: env("SANDCASTLE_CONTAINER", "podman"),
  dryRun: process.env.SANDCASTLE_DRY_RUN === "1",
  oauthToken: env("CLAUDE_CODE_OAUTH_TOKEN"),
  ghToken: env("GH_TOKEN"),
};

const projectPath = process.argv[2];
if (!projectPath || !existsSync(projectPath)) {
  console.error("usage: sandcastle-run <path-to-project-repo>");
  process.exit(2);
}

interface Issue {
  number: number;
  title: string;
  body: string;
  labels: { name: string }[];
}

/**
 * Parse the issue body's "## Blocked by" section into blocker issue numbers.
 * Only the Blocked-by section counts — a "## Parent" reference is NOT a blocker.
 * Section ends at the next markdown heading.
 */
function extractBlockers(body: string): number[] {
  const nums = new Set<number>();
  let inSection = false;
  for (const line of (body ?? "").split(/\r?\n/)) {
    if (/^#+\s*Blocked by/i.test(line)) {
      inSection = true;
      continue;
    }
    if (/^#+\s/.test(line)) inSection = false; // next heading ends the section
    if (inSection) {
      for (const m of line.matchAll(/#(\d+)/g)) nums.add(parseInt(m[1], 10));
    }
  }
  return [...nums];
}

const _stateCache = new Map<number, string>();
function issueState(n: number): string {
  if (!_stateCache.has(n)) {
    try {
      _stateCache.set(n, JSON.parse(gh(["issue", "view", String(n), "--json", "state"])).state);
    } catch {
      // Unknown blocker (deleted / cross-repo / no access) → treat as a blocker.
      _stateCache.set(n, "OPEN");
    }
  }
  return _stateCache.get(n)!;
}

/** Blocker issue numbers that are still open (empty ⇒ runnable). */
function openBlockers(issue: Issue): number[] {
  return extractBlockers(issue.body).filter((b) => issueState(b) === "OPEN");
}

/**
 * Per-project config (the "tiny .sandcastle/" half of the hybrid). Lives in the
 * TARGET repo at <project>/.sandcastle/config.json. Only boot differences:
 *   {
 *     "hostSetupCommands": ["mkdir -p .sandcastle && nix print-dev-env > .sandcastle/devenv.sh"],
 *     "setupCommands": ["bash -lc 'source .sandcastle/devenv.sh && pg-start && npm ci'"]
 *   }
 * hostSetupCommands run on the HOST (where nix fully works) against the worktree;
 * setupCommands run once INSIDE the sandbox after it's ready (before any agent).
 * The host/sandbox share the worktree dir, so an env file written by the former
 * is sourced by the latter — this avoids running nix against the read-only
 * /nix/store mount inside the container.
 */
interface ProjectConfig {
  hostSetupCommands?: string[];
  setupCommands?: string[];
}

function loadProjectConfig(): ProjectConfig {
  const p = join(projectPath, ".sandcastle", "config.json");
  if (!existsSync(p)) return {};
  try {
    return JSON.parse(readFileSync(p, "utf8")) as ProjectConfig;
  } catch (err) {
    console.error(`Warning: could not parse ${p}:`, err);
    return {};
  }
}

function gh(args: string[]): string {
  return execFileSync("gh", args, {
    cwd: projectPath,
    encoding: "utf8",
    env: { ...process.env, GH_TOKEN: cfg.ghToken },
  });
}

function listReadyIssues(): Issue[] {
  const out = gh([
    "issue",
    "list",
    "--label",
    cfg.label,
    "--state",
    "open",
    "--json",
    "number,title,body,labels",
    "--limit",
    "100",
  ]);
  return JSON.parse(out) as Issue[];
}

/**
 * The pure-logic chain. Each entry is one focused `sandbox.run()` on the shared
 * branch; commits accumulate. The agent fetches full issue context itself via
 * `gh issue view` (it has gh + GH_TOKEN inside the sandbox).
 */
interface ChainStep {
  name: string;
  prompt: string;
  maxIterations: number;
  /** A gate step: if it produces 0 commits, the chain aborts for this issue. */
  gate?: boolean;
}

function logicChain(n: number): ChainStep[] {
  const ctx = `You are working autonomously on GitHub issue #${n} in this repository, inside an isolated sandbox. No human is available to answer questions: never ask for input, request confirmation, or wait for approval. Whenever a skill or step would normally ask you to choose between options, pick the recommended option, briefly state which one you chose and why, then proceed. Record any non-trivial assumptions or decisions you make so a human can review them later. First run \`gh issue view ${n} --comments\` to read the full issue (title, body, acceptance criteria, discussion). Work only within the scope of that issue.`;
  return [
    {
      name: "tdd",
      maxIterations: cfg.implementIterations,
      gate: true,
      prompt: `${ctx}\n\nUse the /tdd skill to implement the issue test-first (red → green → refactor). Make all tests pass. Commit your work. When the implementation is complete and the test suite is green, print ${COMPLETE}.`,
    },
    {
      name: "review",
      maxIterations: 10,
      prompt: `${ctx}\n\nRun the /review skill on the changes on this branch (compare against ${cfg.baseBranch}). The skill only PRODUCES a list of findings — it does not apply fixes. You MUST then implement and commit a fix for every blocking finding, then re-run the review and the tests to confirm. Only print ${COMPLETE} once all blocking findings are resolved and committed (if there were none, print it immediately).`,
    },
    {
      name: "codex-review",
      maxIterations: 10,
      prompt: `${ctx}\n\nRun the /codex:review skill on the current branch changes. The skill only REPORTS findings — it does not fix them. You MUST implement and commit a fix for every blocking finding, then re-run codex review to confirm. Only print ${COMPLETE} once codex review is clean and the fixes are committed.`,
    },
    {
      name: "qa-plan",
      maxIterations: 3,
      prompt: `${ctx}\n\nRun the /qa-plan skill for issue #${n}. It cross-references the issue against the diff, smoke-tests the running app, posts a manual QA plan as a comment on issue #${n}, and relabels the issue \`ready-for-human\` (removing \`${cfg.label}\`). In the QA plan comment, also include a short "Autonomous decisions & assumptions" section listing any choices you made without human input during implementation/review (which option you picked and why). Print ${COMPLETE} when the plan is posted.`,
    },
    {
      name: "open-pr",
      maxIterations: 1,
      prompt: `${ctx}\n\nOpen a pull request for this branch targeting \`${cfg.baseBranch}\` using \`gh pr create\`. Title: reference issue #${n}. Body: summarise the work, link the issue with "Refs #${n}" (do NOT use "Closes/Fixes #${n}" — the issue must stay open for human QA), and add an "## Autonomous decisions" section listing any choices made without human input (which option picked and why) plus any remaining assumptions. Print ${COMPLETE} once the PR exists.`,
    },
  ];
}

function buildMounts() {
  const mounts: { hostPath: string; sandboxPath: string; readonly?: boolean }[] =
    [
      { hostPath: "/nix/store", sandboxPath: "/nix/store", readonly: true },
      // nix-managed agent world (symlinks resolve via the /nix/store mount):
      {
        hostPath: `${cfg.claudeDir}/skills`,
        sandboxPath: "~/.claude/skills",
        readonly: true,
      },
      {
        hostPath: `${cfg.claudeDir}/plugins`,
        sandboxPath: "~/.claude/plugins",
        readonly: true,
      },
      {
        hostPath: `${cfg.claudeDir}/agents`,
        sandboxPath: "~/.claude/agents",
        readonly: true,
      },
      {
        hostPath: `${cfg.claudeDir}/commands`,
        sandboxPath: "~/.claude/commands",
        readonly: true,
      },
      {
        hostPath: `${cfg.claudeDir}/CLAUDE.md`,
        sandboxPath: "~/.claude/CLAUDE.md",
        readonly: true,
      },
      // sandbox-tailored settings (bypass perms; host-only hooks stripped):
      {
        hostPath: cfg.settings,
        sandboxPath: "~/.claude/settings.json",
        readonly: true,
      },
    ];
  // ~/.claude/projects + cache stay UNMOUNTED so they're writable in-container
  // (Claude writes session JSONL there; sandcastle captures it back).
  if (cfg.codexAuth && existsSync(cfg.codexAuth)) {
    mounts.push({
      hostPath: cfg.codexAuth,
      sandboxPath: "~/.codex/auth.json",
      readonly: true,
    });
  }
  return mounts.filter((m) => existsSync(m.hostPath));
}

async function processIssue(issue: Issue): Promise<void> {
  const n = issue.number;
  const branch = `agent/issue-${n}`;
  console.log(`\n=== issue #${n}: ${issue.title} → ${branch} ===`);

  if (cfg.dryRun) {
    console.log(`  [dry-run] would run logic chain: ${logicChain(n).map((s) => s.name).join(" → ")}`);
    return;
  }

  const projectCfg = loadProjectConfig();
  const hostSetup = projectCfg.hostSetupCommands ?? [];
  const setup = projectCfg.setupCommands ?? [];
  const hooks =
    hostSetup.length > 0 || setup.length > 0
      ? {
          ...(hostSetup.length > 0
            ? { host: { onWorktreeReady: hostSetup.map((command) => ({ command })) } }
            : {}),
          ...(setup.length > 0
            ? { sandbox: { onSandboxReady: setup.map((command) => ({ command })) } }
            : {}),
        }
      : undefined;

  const sandboxProvider = cfg.container === "docker" ? docker : podman;
  await using sandbox = await createSandbox({
    branch,
    baseBranch: cfg.baseBranch,
    cwd: projectPath,
    sandbox: sandboxProvider({
      imageName: cfg.image,
      mounts: buildMounts(),
      // GH_TOKEN on the SANDBOX provider env; CLAUDE_CODE_OAUTH_TOKEN on the
      // AGENT env below. They MUST be disjoint or sandcastle throws.
      env: { GH_TOKEN: cfg.ghToken },
    }),
    // Per-project boot (pg-start, npm ci, migrations) from <project>/.sandcastle.
    hooks,
  });

  for (const step of logicChain(n)) {
    console.log(`  → ${step.name}`);
    const result = await sandbox.run({
      name: `issue-${n}-${step.name}`,
      maxIterations: step.maxIterations,
      agent: claudeCode(cfg.model, {
        effort: cfg.effort,
        env: { CLAUDE_CODE_OAUTH_TOKEN: cfg.oauthToken },
      }),
      prompt: step.prompt,
      completionSignal: COMPLETE,
      // Per-run file log under <project>/.sandcastle/logs/ (sandcastle's default
      // location). One file per step so a human can see exactly what was done.
      logging: {
        type: "file",
        path: join(projectPath, ".sandcastle", "logs", `issue-${n}-${step.name}.log`),
      },
    });
    console.log(
      `    ${step.name}: ${result.commits.length} commit(s)` +
        (result.completionSignal ? " ✓ complete" : " ⚠ no completion signal") +
        ` · log: ${result.logFilePath ?? "(none)"}`,
    );
    // Commit gate: if the implementation step produced nothing, abort the chain
    // for this issue — don't open an empty PR. Flag it for a human and stop.
    if (step.gate && result.commits.length === 0) {
      console.warn(`  issue #${n}: "${step.name}" produced 0 commits — aborting chain.`);
      try {
        gh([
          "issue", "comment", String(n), "--body",
          "🤖 Autonomous sandcastle run produced no commits for this issue: the implementation step finished without changing anything (it may have stalled, hit an ambiguity it couldn't resolve, or found nothing to do). Flagging for human attention and removing the agent label. See `.sandcastle/logs/` on the runner for the full transcript.",
        ]);
        gh(["issue", "edit", String(n), "--add-label", "needs-info", "--remove-label", cfg.label]);
      } catch (err) {
        console.error(`  issue #${n}: failed to comment/relabel:`, err);
      }
      return;
    }
  }
  console.log(`=== issue #${n} done (branch ${branch}, issue left open) ===`);
}

/** Run `worker` over `items` with at most `limit` in flight at once. */
async function runPool<T>(
  items: T[],
  limit: number,
  worker: (item: T) => Promise<void>,
): Promise<void> {
  let cursor = 0;
  const next = async (): Promise<void> => {
    const i = cursor++;
    if (i >= items.length) return;
    await worker(items[i]);
    await next();
  };
  const workers = Array.from({ length: Math.min(limit, items.length) }, () => next());
  await Promise.all(workers);
}

async function main(): Promise<void> {
  const ready = listReadyIssues();
  // Drop issues whose "Blocked by" section names a still-open issue.
  const runnable: Issue[] = [];
  for (const issue of ready) {
    const ob = openBlockers(issue);
    if (ob.length > 0) {
      console.log(`  skip #${issue.number}: blocked by open ${ob.map((n) => `#${n}`).join(", ")}`);
      continue;
    }
    runnable.push(issue);
  }
  // Lowest issue number first — clear the foundational backlog before newer work.
  runnable.sort((a, b) => a.number - b.number);
  const issues = runnable.slice(0, cfg.maxIssues);
  if (issues.length === 0) {
    console.log(
      `No runnable issues labeled "${cfg.label}" in ${projectPath} ` +
        `(${ready.length} ready, all blocked or none present).`,
    );
    return;
  }
  console.log(
    `Found ${runnable.length} runnable / ${ready.length} ready issue(s); processing ${issues.length} (max ${cfg.maxIssues}), up to ${cfg.concurrency} in parallel.`,
  );
  // Bounded concurrency: each issue runs in its own isolated git worktree
  // (createSandbox always creates one), so parallel runs never collide. A
  // failing issue is logged and does not stop the others. Merges are manual.
  await runPool(issues, Math.max(1, cfg.concurrency), async (issue) => {
    try {
      await processIssue(issue);
    } catch (err) {
      console.error(`issue #${issue.number} FAILED:`, err);
    }
  });
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
