# Hermes prompt — branch-pin sweep

Hand this to Hermes when asking it to clean up branch-tip pins. Self-contained;
don't add context.

---

You are operating inside `/mnt/nas/NixOS` (a NixOS configuration repo). Read
`scripts/AUTO-UPDATE-PLAYBOOK.md` first — the "Sweep: replace branch-tip pins
before they go stale" section explains the pattern, decision tree, and refresh
commands. Apply that section, then return.

## The assignment

Find every Nix fetch that pins to a **branch tip** (not a release tag, not a
commit SHA) and repin it. Branch-tip pins are silent landmines because Nix
caches the first fetched tree by hash, so the source freezes the moment a
build succeeds — and new upstream commits never reach the build until somebody
manually changes the hash. The user has hit this with `litellm`'s
`model_prices_and_context_window.json` (stuck on a months-old `main` snapshot)
and `mattpocock/skills` (pinned to `rev = "main"`). Fix that class, repo-wide.

## Scope

Only fetches that target GitHub. In scope:

- `fetchFromGitHub { rev = "<branch>"; ... }` where `<branch>` ∈ {`main`,
  `master`, `HEAD`, `develop`, `trunk`}.
- `fetchurl`/`fetchzip`/`fetchTarball`/`fetchgit` whose URL contains
  `raw.githubusercontent.com/<owner>/<repo>/(main|master|HEAD)/...` or
  `github.com/<owner>/<repo>/raw/(refs/heads/(main|master)|main|master)/...`.

Out of scope this run: non-GitHub sources, flake inputs, packages that are
already on a tag or SHA.

## Procedure per hit

For each branch-tip pin:

1. **Pick the new ref.**
   - Does upstream publish release tags?
     `git ls-remote --tags --refs <repo-url> | tail`.
     If yes → use the **latest stable tag** (skip `-rc.*`, `-dev.*`,
     `-pre.*`, `-beta`, `-alpha` suffixes).
   - No tags?
     `git ls-remote <repo-url> refs/heads/<branch>`.
     Use the SHA the branch points to *right now* and leave a one-line
     comment naming the tracked branch so the next bump knows which ref to
     re-check.

2. **Refresh the hash.**
   - GitHub source tree:
     `nix flake prefetch github:<owner>/<repo>/<rev> --json` — paste the
     `hash` field.
   - Raw file:
     `nix store prefetch-file --json --hash-type sha256 "<url>"` — paste
     the `hash` field.
   - Do **not** use the fake-hash (`sha256-AAA…`) loop for these. There is
     no narrow build step; prefetch is faster and quieter.

3. **Rewrite the source.** Use `${...}` interpolation so the version
   string appears exactly once, where the URL substitution loop in
   `nix-github-update-report.py` can find and bump it next time:

   ```nix
   # Tag-pinned raw file:
   let
     litellmRelease = "v1.86.2";
   in
   fetchurl {
     url = "https://raw.githubusercontent.com/BerriAI/litellm/refs/tags/${litellmRelease}/model_prices_and_context_window.json";
     hash = "sha256-...";
   }

   # SHA-pinned source (tracks a branch by SHA):
   fetchFromGitHub {
     owner = "mattpocock";
     repo = "skills";
     # Tracks main; bump SHA + hash to pull new skills.
     rev = "<40-char-SHA>";
     hash = "sha256-...";
   }
   ```

4. **Narrow-build only when the fetch feeds a `pkgs/<name>/package.nix`
   derivation.** For files under `users/.../*.nix` or shared modules,
   prefetch alone is sufficient — those don't have a per-package build
   target.

5. **Format.** `alejandra <file>` on every file you touch.

6. **Do not commit.** Leave the working tree dirty; the user reviews
   before committing.

## Failure modes to expect

- **No tags AND no recent commits on the branch (stale upstream).** Leave
  the file untouched and note it in your summary as
  "<file>:<line> — stale upstream, manual decision".
- **Branch SHA produces a different hash than the one already in the
  file.** That's the whole point — the cache silently aged out. Paste the
  new hash.
- **Hash matches what's already there.** Means the cached tree already
  matched the branch tip at write-time. Keep the SHA pin anyway; the file
  is no longer a landmine even if today's content is identical.
- **Source tree no longer has the file path that downstream code
  references** (e.g. `.claude-plugin/plugin.json` moved). Verify against
  the prefetched store path and update downstream paths before
  finalizing the bump.

## Return shape

Report a punch list:

```
fixed:
  - <file>:<line> — <owner>/<repo> rev `<old>` → `<new>` (<tag|sha>)
skipped:
  - <file>:<line> — <reason>
```

Under 200 words. Don't paste diffs; the user reads the working tree.
