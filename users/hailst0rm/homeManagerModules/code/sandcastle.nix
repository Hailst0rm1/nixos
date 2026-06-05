{
  config,
  lib,
  pkgs,
  mkSecretEnvWrapper,
  ...
}: let
  cfg = config.code.sandcastle;

  nodejs = pkgs.nodejs_22;

  # Selected container runtime. The matching NixOS runtime is auto-enabled by
  # nixosModules/services/sandcastle-runtime.nix (HM can't set virtualisation.*).
  containerPkg =
    if cfg.container == "docker"
    then pkgs.docker
    else pkgs.podman;
  containerBin = "${containerPkg}/bin/${cfg.container}";

  # Orchestrator sources (orchestrator.ts + package.json) as a store path.
  orchestratorSrc = ./sandcastle;

  # Sandbox-tailored Claude settings, mounted over the agent's ~/.claude. It
  # deliberately omits the host hooks (RTK rewrite, paplay sound, session-handoff
  # reminder, statusline) — those need host binaries/audio absent in the
  # container. Permissions are moot (sandcastle forces --dangerously-skip-
  # permissions), so we keep this minimal.
  sandboxSettings = pkgs.writeText "sandcastle-claude-settings.json" (builtins.toJSON {
    env = {
      DISABLE_AUTOUPDATER = "1";
      DISABLE_TELEMETRY = "1";
      CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
    };
    includeCoAuthoredBy = false;
  });

  # Runner: sync the read-only orchestrator sources into a writable state dir,
  # install node deps on first run (documented impurity — harden later with
  # buildNpmPackage + a committed lockfile), then exec it. The container
  # runtime/git/gh must be on PATH for sandcastle's shell-outs.
  runner = pkgs.writeShellScript "sandcastle-runner" ''
    set -euo pipefail
    export PATH="${lib.makeBinPath [nodejs pkgs.git pkgs.gh pkgs.rsync containerPkg]}:$PATH"
    # Rootless podman resolves the user's /etc/subuid range by $USER. Some launch
    # contexts leak a bogus USER (e.g. "Administrator" from a remote/RDP session)
    # that has no subuid entry, so podman silently falls back to a single-id
    # userns. That makes the agent container's `podman exec --user 0:0` setup step
    # fail with `crun: setresgid to 0: Invalid argument`. Pin USER to the real
    # account so subid lookup — and the full uid/gid range mapping — succeed.
    export USER="$(${pkgs.coreutils}/bin/id -un)"
    # Resolve the project path (first positional arg) to an ABSOLUTE path while we
    # are still in the user's invocation directory. We cd into $STATE below, after
    # which a relative path like "." would resolve against the state dir instead of
    # the user's repo — breaking the orchestrator's `gh`/`git` calls.
    if [ "$#" -ge 1 ]; then
      if project="$(cd "$1" 2>/dev/null && pwd)"; then
        shift
        set -- "$project" "$@"
      else
        echo "sandcastle: '$1' is not a directory" >&2
        exit 2
      fi
    fi
    STATE="''${XDG_STATE_HOME:-$HOME/.local/state}/sandcastle"
    mkdir -p "$STATE"
    ${pkgs.rsync}/bin/rsync -a --delete --chmod=u+w \
      --exclude node_modules "${orchestratorSrc}/" "$STATE/"
    cd "$STATE"
    # Reinstall whenever the orchestrator sources change. orchestratorSrc is a
    # content-addressed store path, so ANY edit to orchestrator.ts or
    # package.json yields a new path — this nukes a stale node_modules +
    # package-lock.json (the store ships no lock) and reinstalls cleanly.
    if [ ! -d node_modules ] || [ "$(cat .src 2>/dev/null)" != "${orchestratorSrc}" ]; then
      echo "sandcastle: (re)installing orchestrator dependencies…" >&2
      rm -rf node_modules package-lock.json
      ${nodejs}/bin/npm install --no-audit --no-fund --loglevel=error
      echo "${orchestratorSrc}" > .src
    fi
    exec "$STATE/node_modules/.bin/tsx" orchestrator.ts "$@"
  '';

  sandcastleRun = mkSecretEnvWrapper {
    name = "sandcastle-run";
    bin = true;
    env = {
      CLAUDE_CODE_OAUTH_TOKEN = "services/anthropic/claude-oauth-token";
      GH_TOKEN = "services/github/sandcastle-pat";
    };
    staticEnv = {
      SANDCASTLE_IMAGE = cfg.image;
      SANDCASTLE_CLAUDE_DIR = "${config.home.homeDirectory}/.claude";
      SANDCASTLE_SETTINGS = "${sandboxSettings}";
      SANDCASTLE_CODEX_AUTH = "${config.home.homeDirectory}/.codex/auth.json";
      SANDCASTLE_MODEL = cfg.model;
      SANDCASTLE_EFFORT = cfg.effort;
      SANDCASTLE_BASE_BRANCH = cfg.baseBranch;
      SANDCASTLE_MAX_ISSUES = toString cfg.maxIssues;
      SANDCASTLE_CONCURRENCY = toString cfg.concurrency;
      SANDCASTLE_IMPLEMENT_ITERATIONS = toString cfg.implementIterations;
      SANDCASTLE_CONTAINER = cfg.container;
    };
    command = "${runner}";
  };

  # Convenience: build the agent image and load it into the selected runtime.
  # Run from the flake root. The runtime is auto-enabled when sandcastle is on
  # (see nixosModules/services/sandcastle-runtime.nix); needs a host rebuild.
  loadImage = pkgs.writeShellScriptBin "sandcastle-load-image" ''
    set -euo pipefail
    cd "''${1:-$HOME/.nixos}"
    echo "Building .#sandcastle-agent-image…" >&2
    ${pkgs.nix}/bin/nix build .#sandcastle-agent-image
    echo "Loading into ${cfg.container}…" >&2
    ${containerBin} load < result
    echo "Tagging as ${cfg.image}…" >&2
    ${containerBin} tag sandcastle-agent:latest ${cfg.image} || true
    ${containerBin} images | ${pkgs.gnugrep}/bin/grep sandcastle || true
  '';
in {
  options.code.sandcastle = {
    enable = lib.mkEnableOption "the autonomous sandcastle agent pipeline";
    container = lib.mkOption {
      type = lib.types.enum ["podman" "docker"];
      default = "podman";
      description = "Container runtime sandcastle runs agents in. Auto-enables the matching NixOS runtime (see nixosModules/services/sandcastle-runtime.nix).";
    };
    image = lib.mkOption {
      type = lib.types.str;
      default = "sandcastle-agent:latest";
      description = "Image name the orchestrator runs agents in (load it with `sandcastle-load-image`).";
    };
    model = lib.mkOption {
      type = lib.types.str;
      default = "claude-opus-4-7";
      description = "Claude model used for every chain step.";
    };
    effort = lib.mkOption {
      type = lib.types.enum ["low" "medium" "high" "xhigh" "max"];
      default = "high";
      description = "Claude Code reasoning effort for every chain step.";
    };
    baseBranch = lib.mkOption {
      type = lib.types.str;
      default = "master";
      description = "Branch agents fork from and target PRs against.";
    };
    maxIssues = lib.mkOption {
      type = lib.types.int;
      default = 4;
      description = "Max ready-for-agent issues processed per invocation.";
    };
    concurrency = lib.mkOption {
      type = lib.types.int;
      default = 2;
      description = "Max issues worked in parallel (each in its own isolated git worktree). Mind your Claude subscription's concurrency limit.";
    };
    implementIterations = lib.mkOption {
      type = lib.types.int;
      default = 40;
      description = "Upper bound on agent re-invocations for the implementation (tdd) step; it stops early on the completion signal.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.importConfig.sops.enable;
        message = "code.sandcastle requires importConfig.sops.enable (CLAUDE_CODE_OAUTH_TOKEN + sandcastle-pat come from sops).";
      }
    ];
    home.packages = [
      sandcastleRun
      loadImage
      nodejs
    ];
  };
}
