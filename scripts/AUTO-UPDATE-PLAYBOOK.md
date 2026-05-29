# Nix GitHub Auto-Update Playbook

Hermes should read this before each `scripts/nix-github-update-report.py
--auto-update-all` run.

## Diagnose narrow build failures before rolling back

When the narrow build fails after a fetch-hash refresh, the failure is almost
always one of the four classes below. **Diagnose before rolling back.** Blind
rollback re-queues the same package next run, wasting CPU and the user's
attention.

### 1. Patch hunk failed

**Symptom.** During `patchPhase`:

```
applying patch ./<name>.patch
Hunk #1 FAILED at <N>.
1 out of 1 hunk FAILED -- saving rejects to file <path>.rej
```

A `patches = [...]` entry no longer applies cleanly. Two sub-cases:

- **(a) Upstream merged the same fix.** New source already contains the
  patched lines — the patch is obsolete.
- **(b) Upstream took a different approach.** Anchor lines moved.

**Diagnose.** Prefetch the new rev and read the patched file from the store:

```sh
PREFETCH_JSON=$(nix flake prefetch github:<owner>/<repo>/<new-rev> --json)
STORE_PATH=$(echo "$PREFETCH_JSON" | jq -r .storePath)
sed -n '<line>,<line>p' "$STORE_PATH/<path-from-patch-file>"
```

**Fix (a).** Drop the patch:
1. Remove the entry from `patches = [...];` (delete the attribute if last one).
2. Delete the patch file from disk.
3. Re-run the narrow build.

**Fix (b).** Re-derive the patch against the new file. Don't refresh hashes —
won't help.

**Example.** `pkgs/hermes-agent/codex-transport-tools-none.patch` was case (a)
on v2026.5.16 → v2026.5.29 — upstream incorporated the patch verbatim. Patch
was removed, file deleted.

### 2. Python dependency missing at runtime

**Symptom.**

```
ModuleNotFoundError: No module named '<X>'
# or
<X> not installed
```

The hand-maintained `dependencies = [...]` / `propagatedBuildInputs = [...]`
list drifted from upstream `pyproject.toml`.

**Fix.** Read upstream's pyproject from the prefetched store path and mirror
`[project.dependencies]` into the Nix `dependencies` attr:

```sh
PREFETCH_JSON=$(nix flake prefetch github:<owner>/<repo>/<new-rev> --json)
STORE_PATH=$(echo "$PREFETCH_JSON" | jq -r .storePath)
grep -A50 '^\[project\]' "$STORE_PATH/pyproject.toml"
```

For each name in `[project.dependencies]` not already in the Nix list, add
`python3.pkgs.<name>`. Upstream names usually match nixpkgs identifiers
verbatim — when uncertain, consult the `nix` MCP tool.

**Do NOT** auto-add `[project.optional-dependencies]` (a.k.a. extras). Only
mirror an extra when the Nix wrapper or `postFixup` actually invokes it.
Conversely, **don't remove** an existing dep just because upstream demoted
it to an extra (e.g. `playwright` moving from `dependencies` to `[browser]`)
— if `wrapProgram` still sets `PLAYWRIGHT_BROWSERS_PATH`, you still need it.

**Example.** `notebooklm-py` v0.4.1 → v0.5.0 added `filelock>=3.13,<4` to
`[project.dependencies]`. Fix was a one-line addition of `filelock` to the
Nix `dependencies` list; `playwright` stayed because the wrapper still uses
it.

### 3. crates.io 403 during cargo vendor

**Symptom.**

```
Exception: Failed to fetch file from https://crates.io/api/v1/crates/<crate>/<version>/download. Status code: 403
# or
curl: (22) The requested URL returned error: 403
error: cannot download crate-<crate>-<version>.tar.gz from any mirror
```

**Cause.** crates.io denies requests from the Nix sandbox's fetcher when the
host's IP or the fetcher's User-Agent is on a denylist:
- `fetch-cargo-vendor-util` uses `python-requests/X.Y.Z` UA.
- `importCargoLock` uses Nix's `fetchurl` → curl with default UA.
- Both have been observed to 403 from the same host.

This affects **every** Rust package built on the affected host, not just the
one in the report.

**What does NOT work (verified 2026-05-29):**

- Switching `cargoHash` → `cargoLock = { lockFile = ./Cargo.lock; }`. The
  resulting `fetchurl` curl gets 403 too.
- `useFetchCargoVendor = false`. nixpkgs ≥25.05 makes
  `useFetchCargoVendor = true` non-optional — Nix refuses to evaluate.

**Diagnose.**

1. **Retry the exact same build once.** If transient rate-limit, succeeds on
   second attempt — paste cargoHash and move on.
2. **Probe from outside the sandbox.** If
   ```sh
   nix-shell -p python3 --run \
     'python3 -c "import urllib.request as u; print(u.urlopen(\"https://crates.io/api/v1/crates/adler2/2.0.1/download\").status)"'
   ```
   prints `200`, the host can reach crates.io. If the build still 403s, the
   sandbox-level fetcher is being denied specifically.

**Fix.**

- **(a) Transient (single retry succeeded).** Update `cargoHash`, done.
- **(b) Persistent.** Revert the package file to identical bytes (do not churn
  the diff) and skip this package. The failure is network policy, not a
  package issue. Surface the skip in the auto-update report output so the
  user knows it needs upstream nixpkgs work or a host network change.

**Example.** `rtk` v0.40.0 → v0.42.0 hit case (b) on 2026-05-29: `adler2/2.0.1`
403'd via both `python-requests` (`fetch-cargo-vendor-util`) and curl
(`importCargoLock`) from the build sandbox. Plain Python urllib from outside
the sandbox returned 200 for the same URL. The crate is real and pinned in
upstream `Cargo.lock`; the host's sandboxed request is being denied at the
network layer. Reverted to v0.40.0 with zero package changes.

### 4. FOD outputHash mismatch — pip download / npm ci / etc.

**Symptom.**

```
error: hash mismatch in fixed-output derivation '...':
         specified: sha256-OLD
            got:    sha256-NEW
```

A multi-step FOD (e.g. `hermes-wheels` from `pip download`,
`hermes-web-modules` from `npm ci`) is keyed on `src`, so the FOD's hash
changes with every source bump even if the lockfile didn't.

**Fix.** Same fake-hash trick the script already runs for `cargoHash` /
`vendorHash` / `npmDepsHash` / `pnpmDepsHash` / `yarnHash`, extended to every
literal `outputHash = "sha256-...";` in the file:

1. Set the offending `outputHash` to
   `sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=`.
2. Re-run the build; copy the `got:` value back.
3. Repeat per FOD until the top-level derivation builds.

Use a different placeholder per FOD (`AAA…A`, `BBB…B`, …) so a missed paste
doesn't accidentally produce two FODs with the same fake hash.

**Example.** `hermes-agent` v2026.5.16 → v2026.5.29 had two FODs to refresh:
`hermes-wheels` (pip download of `.[all,messaging]`) and `hermes-web-modules`
(npm ci against the new package-lock). Both refreshed via the AAA/BBB trick.

## Rollback rule of thumb

Roll back **only** when:

- Failure is not class 1 (`hunk FAILED`).
- Failure is not class 2 (missing Python module).
- Failure is class 3 case (b) (persistent crates.io 403) — and even then,
  revert to identical bytes; don't leave a churned diff behind.
- Failure is not class 4 (refreshable `outputHash` mismatch in an FOD).

For everything else: apply the targeted fix first. Re-running the narrow
build after a targeted fix is cheap; making the user re-discover the same
regression next day is expensive.

## Possible script improvements

These changes to `scripts/nix-github-update-report.py` would let it diagnose
the four classes itself instead of always rolling back:

- **Class 1.** On `hunk FAILED`, prefetch the new rev, fetch the patch target
  file, and run `patch --dry-run --reverse`. If reverse-applies cleanly, the
  patch is already upstream — emit "obsolete patch" and offer to drop the
  entry and delete the file.
- **Class 2.** On `ModuleNotFoundError` / `<X> not installed`, prefetch the
  new rev, parse its `pyproject.toml`, diff `[project.dependencies]` against
  the in-file `dependencies = [...]` list, and emit (or apply under
  `--auto-update`) the missing entries as `python3.pkgs.<name>`.
- **Class 3.** Match the exact "Status code: 403" /
  "cannot download crate-... from any mirror" patterns. Probe crates.io once
  from outside the sandbox (`python3 -c 'import urllib.request as u; …'`); if
  host can reach but sandbox cannot, emit "crates.io blocks sandbox fetcher
  on this host — package skipped" and leave the file untouched.
- **Class 4.** Extend `build_with_dependency_hash_retries` to also iterate
  every literal `outputHash = "sha256-...";` in the file using the same
  fake-hash loop already in use for `cargoHash`, `vendorHash`, etc.

Class 3 is the highest-value addition — current behaviour silently rolls back
and re-attempts the same package next day.
