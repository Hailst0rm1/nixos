#!/usr/bin/env bash
# zsh-history-sync — per-host append-only files, conflict-free GitHub sync.
#
# Design: the repo holds one file per host (hosts/<host>.zhist), append-only,
# each with a SINGLE writer. Disjoint files => git never conflicts and pushes
# are never rejected for content. The live HISTFILE stays local (git never
# touches it), and a read-only merged view is built for `fc -R`.
#
# Subcommands:
#   push   pull (rebase) -> append local delta to hosts/<host>.zhist -> commit
#          -> push (retry) -> rebuild merged view
#   pull   pull (rebase) -> rebuild merged view              (login/read side)
#   merged-path   print the merged-view file path
#
# Configured entirely via env so it is testable outside Nix and reusable in
# the NixOS module:
#   ZHS_HISTFILE   live zsh history file (this host's own history)
#   ZHS_REPO_DIR   git clone of the sync repo
#   ZHS_REPO_URL   remote URL (used only to clone if REPO_DIR is absent)
#   ZHS_HOST       hostname -> hosts/<host>.zhist
#   ZHS_STATE_DIR  marker + merged view live here
#   ZHS_BRANCH     branch (default: main)
#   ZHS_RETRIES    push retries on non-fast-forward (default: 5)
#   ZHS_RETRY_SLEEP seconds between retries (default: 3; 0 in tests)
#   GIT_SSH_COMMAND  (optional) e.g. ssh -i <deploy-key> -o IdentitiesOnly=yes
#
# Exit codes: 0 ok; non-zero only on unrecoverable error. Network/push failures
# are tolerated (logged) so they never block login or shutdown.

set -u

ZHS_BRANCH="${ZHS_BRANCH:-main}"
ZHS_RETRIES="${ZHS_RETRIES:-5}"
ZHS_RETRY_SLEEP="${ZHS_RETRY_SLEEP:-3}"

log()  { printf '[zhs] %s\n' "$*" >&2; }
err()  { printf '[zhs:error] %s\n' "$*" >&2; }

require_env() {
  local missing=0 v
  for v in ZHS_HISTFILE ZHS_REPO_DIR ZHS_HOST ZHS_STATE_DIR; do
    if [ -z "${!v:-}" ]; then err "missing required env: $v"; missing=1; fi
  done
  [ "$missing" -eq 0 ] || exit 2
}

git_q() { git -C "$ZHS_REPO_DIR" "$@"; }

# Per-host commit identity so systemd services (which lack interactive git
# config) can still commit.
git_commit() {
  git_q \
    -c "user.name=zsh-history-sync" \
    -c "user.email=zsh-history-sync@${ZHS_HOST}" \
    commit "$@"
}

host_file() { printf '%s/hosts/%s.zhist' "$ZHS_REPO_DIR" "$ZHS_HOST"; }
marker_file() { printf '%s/%s.offset' "$ZHS_STATE_DIR" "$ZHS_HOST"; }
merged_file() { printf '%s/merged.zhist' "$ZHS_STATE_DIR"; }

ensure_repo() {
  mkdir -p "$ZHS_STATE_DIR"
  if [ -d "$ZHS_REPO_DIR/.git" ]; then return 0; fi
  if [ -z "${ZHS_REPO_URL:-}" ]; then
    err "repo $ZHS_REPO_DIR absent and ZHS_REPO_URL unset"
    return 1
  fi
  log "cloning $ZHS_REPO_URL -> $ZHS_REPO_DIR"
  git clone --branch "$ZHS_BRANCH" "$ZHS_REPO_URL" "$ZHS_REPO_DIR" 2>/dev/null \
    || git clone "$ZHS_REPO_URL" "$ZHS_REPO_DIR"
}

# Pull, tolerating "nothing upstream yet" and offline. Rebase keeps our
# host-file commits linear; --autostash guards a dirty tree.
pull_rebase() {
  git_q pull --rebase --autostash origin "$ZHS_BRANCH" >/dev/null 2>&1 || true
}

# ---- record-aware delta extraction -------------------------------------------
# Emit only COMPLETE history records from the byte range [marker, size) of the
# histfile, and report the number of bytes actually consumed (advances marker).
# A record spans physical lines; every interior line ends with a backslash, the
# final line does not. LC_ALL=C makes awk length() count bytes (UTF-8 safe).
# A trailing record with no newline terminator (a half-written entry) is left
# unconsumed for the next run.
append_delta() {
  local hf="$ZHS_HISTFILE" hostf marker cur slice consumed
  hostf="$(host_file)"
  mkdir -p "$(dirname "$hostf")"
  [ -f "$hostf" ] || : > "$hostf"

  if [ ! -f "$hf" ]; then log "no local histfile yet ($hf)"; return 0; fi

  cur=$(stat -c%s "$hf")
  marker=$(cat "$(marker_file)" 2>/dev/null || echo 0)
  case "$marker" in ''|*[!0-9]*) marker=0;; esac
  # histfile shrank/rotated (e.g. cleared) -> re-sync from start. Append-only
  # to the repo means this only ever duplicates (deduped on read), never loses.
  if [ "$marker" -gt "$cur" ]; then
    log "histfile shrank ($cur < marker $marker); resyncing from 0"
    marker=0
  fi
  [ "$marker" -lt "$cur" ] || { log "no new local history"; return 0; }

  slice=$(mktemp)
  tail -c "+$((marker + 1))" "$hf" | head -c "$((cur - marker))" > "$slice"

  local recs; recs=$(mktemp)
  # Records go to $recs (stdout); bytes-consumed count goes to $recs.bytes (stderr).
  LC_ALL=C gawk '
    BEGIN { RS="\n"; have=0; rec=""; reclen=0; consumed=0 }
    {
      if (RT == "") { exit }                # half-written trailing line: stop
      lb = length($0) + 1
      rec = rec $0 "\n"; reclen += lb; have=1
      if ($0 !~ /\\$/) {                    # final line of record (no cont.)
        printf "%s", rec
        consumed += reclen
        have=0; rec=""; reclen=0
      }
    }
    END { print consumed > "/dev/stderr" }
  ' "$slice" >"$recs" 2>"$recs.bytes"
  consumed=$(cat "$recs.bytes")
  case "$consumed" in ''|*[!0-9]*) consumed=0;; esac

  if [ "$consumed" -gt 0 ]; then
    cat "$recs" >> "$hostf"
    printf '%s' "$((marker + consumed))" > "$(marker_file)"
    log "appended $consumed bytes of new history to $(basename "$hostf")"
  else
    log "no complete new records to append"
  fi
  rm -f "$slice" "$recs" "$recs.bytes"
}

# ---- merged view -------------------------------------------------------------
# Concatenate every host file EXCEPT our own (own history is auto-loaded from
# HISTFILE by zsh), dedup keeping the latest timestamp per command, sort by
# timestamp ascending. Output is a throwaway file consumed by `fc -R` — it is
# never committed, so the dedup/sort can never diverge the repo.
build_merged() {
  local own merged tmp; own="$(host_file)"; merged="$(merged_file)"; tmp=$(mktemp)
  shopt -s nullglob
  local f
  for f in "$ZHS_REPO_DIR"/hosts/*.zhist; do
    [ "$f" = "$own" ] && continue
    cat "$f" >> "$tmp"
  done
  shopt -u nullglob

  LC_ALL=C gawk '
    function store(){ if (cur_cmd!="" || cur_block!=""){ if(!(k in ts)||cur_ts>ts[k]){cmd[k]=cur_block; ts[k]=cur_ts} } }
    BEGIN{ cur_cmd=""; cur_block=""; cur_ts=0; ml=0 }
    /^: *[0-9]+:[0-9]+;/ {
      if (cur_cmd!="" || cur_block!="") { store() }
      match($0, /^: *([0-9]+):[0-9]+;(.*)$/, a); cur_ts=a[1]+0; cur_cmd=a[2]; cur_block=$0; k=cur_cmd
      if ($0 ~ /\\$/) { ml=1 } else { ml=0; store(); cur_cmd=""; cur_block="" }
      next
    }
    ml {
      cur_cmd=cur_cmd "\n" $0; cur_block=cur_block "\n" $0; k=cur_cmd
      if ($0 !~ /\\$/){ ml=0; store(); cur_cmd=""; cur_block="" }
      next
    }
    END{ n=asorti(ts, sk, "@val_num_asc"); for(i=1;i<=n;i++) print cmd[sk[i]] }
  ' "$tmp" > "$merged.tmp" && mv "$merged.tmp" "$merged"
  rm -f "$tmp"
  log "merged view: $(grep -c '^: ' "$merged" 2>/dev/null || echo 0) entries -> $merged"
}

push_with_retry() {
  local i
  for i in $(seq 1 "$ZHS_RETRIES"); do
    if git_q push origin "$ZHS_BRANCH" 2>/dev/null; then return 0; fi
    log "push rejected (attempt $i/$ZHS_RETRIES); pull --rebase and retry"
    pull_rebase
    [ "$ZHS_RETRY_SLEEP" = 0 ] || sleep "$ZHS_RETRY_SLEEP"
  done
  git_q push origin "$ZHS_BRANCH"   # final attempt, surface the error
}

cmd_push() {
  require_env
  ensure_repo || { err "no repo; cannot push"; return 1; }
  # Serialize concurrent push runs (periodic timer vs shutdown).
  exec 9>"$ZHS_STATE_DIR/.push.lock"
  flock 9
  pull_rebase
  append_delta
  if [ -n "$(git_q status --porcelain -- "hosts/${ZHS_HOST}.zhist")" ]; then
    git_q add -- "hosts/${ZHS_HOST}.zhist"
    git_commit -q -m "${ZHS_HOST}: $(date '+%Y-%m-%dT%H:%M:%S%z')"
  else
    log "no new changes to commit"
  fi
  # Push whenever we are ahead of the remote. This also flushes commits left
  # unpushed by an earlier offline run, even when this run added no new delta.
  local ahead
  ahead=$(git_q rev-list --count "origin/${ZHS_BRANCH}..HEAD" 2>/dev/null || echo 0)
  case "$ahead" in ''|*[!0-9]*) ahead=0;; esac
  if [ "$ahead" -gt 0 ]; then
    log "branch ahead by $ahead commit(s); pushing"
    push_with_retry || err "push failed (offline?); will retry next cycle"
  fi
  build_merged
}

cmd_pull() {
  require_env
  ensure_repo || { err "no repo; cannot pull"; return 1; }
  pull_rebase
  build_merged
}

case "${1:-}" in
  push)        cmd_push ;;
  pull)        cmd_pull ;;
  merged-path) merged_file ;;
  *) err "usage: $0 {push|pull|merged-path}"; exit 64 ;;
esac
