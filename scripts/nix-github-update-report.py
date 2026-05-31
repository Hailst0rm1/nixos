#!/usr/bin/env python3
"""Report and experimentally update GitHub-sourced Nix package fetches.

This intentionally treats the Nix repo as the source of truth:
- no manually maintained package watchlist
- flake inputs are ignored
- package/source fetch inventory is generated and cached automatically

It detects GitHub sources in derivation-like blocks using:
- fetchFromGitHub
- fetchurl/fetchzip/fetchTarball/fetchgit with GitHub URLs

Default mode is read-only. Experimental auto-update mode is deliberately narrow:
- only unique, outdated, unpinned fetchFromGitHub source packages
- only package files under pkgs/<name>/package.nix by default
- updates version/rev/hash
- runs a narrow nix build
- rolls back the edited file on failure unless --keep-failed is passed
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Iterable

SCANNER_VERSION = 4
DEFAULT_CACHE = ".hermes-cache/nix-github-fetches.json"

# Generated policy, not a human-maintained watchlist.
# Sliver 1.5.44 is intentionally pinned for compatibility/testing.
PINNED_FETCHES = {
    ("pkgs/sliver-1.5.44/package.nix", "BishopFox", "sliver"),
}

FETCH_FUNCS = r"(?:fetchurl|fetchzip|fetchTarball|fetchgit)"
ASSIGN_RE = lambda name: re.compile(r"\b" + re.escape(name) + r"\s*=\s*(?:rec\s*)?([^;]+);", re.S)
STR_RE = re.compile(r'^\s*"([^"]*)"\s*$')
GITHUB_URL_RE = re.compile(
    r"https://(?:github\.com|raw\.githubusercontent\.com)/"
    r"([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)(?:/([^\"\s]*))?"
)
DERIVATION_RE = re.compile(
    r"(?ms)"
    r"(?:^\s*([A-Za-z_][A-Za-z0-9_-]*)\s*=\s*)?"
    r"(?:[A-Za-z0-9_.-]+\.)?"
    r"(?:mkDerivation|build[A-Za-z0-9_]*Package|buildGoModule|buildNpmPackage|buildPythonApplication|buildPythonPackage)"
    r"\s*(?:rec\s*)?\{"
)


@dataclass
class FetchItem:
    package: str
    path: str
    kind: str
    source_kind: str
    owner: str
    repo: str
    current: str | None
    rev_or_url: str | None
    pinned: bool = False
    # Branch named in an adjacent `# track-branch: <branch>` comment. When set,
    # the item is bumped to that branch's live HEAD SHA instead of a tag.
    track_branch: str | None = None


@dataclass
class ReportItem(FetchItem):
    latest: str | None = None
    latest_url: str | None = None
    latest_error: str | None = None
    tag_count: int = 0
    status: str = "unknown"  # update | ok | unknown | pinned
    current_normalised: str | None = None
    latest_normalised: str | None = None


def run(cmd: list[str], cwd: Path | None = None, timeout: int = 60) -> str:
    return subprocess.check_output(cmd, cwd=cwd, text=True, timeout=timeout, stderr=subprocess.STDOUT)


def run_result(cmd: list[str], cwd: Path | None = None, timeout: int = 600) -> tuple[int, str]:
    proc = subprocess.run(cmd, cwd=cwd, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=timeout)
    return proc.returncode, proc.stdout


def strip_comments(text: str) -> str:
    # Good enough for metadata assignments in Nix package files.
    return re.sub(r"(?m)#.*$", "", text)


def eval_simple(expr: str, ctx: dict[str, str]) -> str:
    expr = expr.strip()
    m = STR_RE.match(expr)
    if m:
        value = m.group(1)
        return re.sub(
            r"\$\{([A-Za-z_][A-Za-z0-9_-]*)\}",
            lambda mm: str(ctx.get(mm.group(1), "${" + mm.group(1) + "}")),
            value,
        )
    if re.match(r"^[A-Za-z_][A-Za-z0-9_-]*$", expr):
        return ctx.get(expr, expr)
    return expr.replace("\n", " ").strip()


def find_matching_brace(text: str, open_idx: int) -> int | None:
    depth = 0
    in_string = False
    escaped = False
    for i, ch in enumerate(text[open_idx:], open_idx):
        if in_string:
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == '"':
                in_string = False
        else:
            if ch == '"':
                in_string = True
            elif ch == "{":
                depth += 1
            elif ch == "}":
                depth -= 1
                if depth == 0:
                    return i
    return None


def attrs_ctx(block: str) -> dict[str, str]:
    ctx: dict[str, str] = {}
    clean = strip_comments(block)
    for name in ["pname", "name", "version"]:
        m = ASSIGN_RE(name).search(clean)
        if m:
            ctx[name] = eval_simple(m.group(1), ctx)
    return ctx


def get_attr(block: str, name: str, ctx: dict[str, str]) -> str | None:
    m = ASSIGN_RE(name).search(strip_comments(block))
    return eval_simple(m.group(1), ctx) if m else None


TRACK_BRANCH_RE = re.compile(r"#\s*track-branch:\s*([^\s#]+)")


def find_track_branch(text: str, pos: int, window: int = 600) -> str | None:
    """Return the branch named in a `# track-branch: <branch>` comment that
    immediately precedes the fetch starting at `pos`, if any."""
    start = max(0, pos - window)
    matches = list(TRACK_BRANCH_RE.finditer(text, start, pos))
    return matches[-1].group(1) if matches else None


def normalise_version(value: str | None) -> str | None:
    if not value:
        return None
    v = str(value).strip().replace("refs/tags/", "")
    v = re.sub(r"\^\{\}$", "", v)
    for prefix in ["release-", "version-", "releases/", "mac-"]:
        if v.lower().startswith(prefix):
            v = v[len(prefix) :]
    if v.startswith("v") and len(v) > 1 and v[1].isdigit():
        v = v[1:]
    return v


def parse_version(value: str | None):
    if not value:
        return None
    v = normalise_version(value)
    if not v or "${" in v or v in {"HEAD", "main", "master", "unstable", "latest"}:
        return None
    m = re.search(r"(\d+(?:\.\d+){1,4})(?:[-+._]?([A-Za-z][A-Za-z0-9.-]*\d*))?$", v)
    if not m:
        return None
    nums = tuple(int(x) for x in m.group(1).split("."))
    suffix = m.group(2) or ""
    prerelease = bool(re.search(r"(alpha|beta|rc|pre|dev|nightly|canary|snapshot)", suffix, re.I))
    return nums, prerelease, suffix


def is_newer(latest: str | None, current: str | None) -> bool | None:
    latest_v = parse_version(latest)
    current_v = parse_version(current)
    if not latest_v or not current_v:
        return None
    latest_nums, latest_pre, _ = latest_v
    current_nums, current_pre, _ = current_v
    width = max(len(latest_nums), len(current_nums))
    latest_nums = latest_nums + (0,) * (width - len(latest_nums))
    current_nums = current_nums + (0,) * (width - len(current_nums))
    if latest_nums != current_nums:
        return latest_nums > current_nums
    return (not latest_pre) and current_pre


def source_kind_from_url_tail(tail: str | None) -> str:
    tail = tail or ""
    if tail.startswith("releases/download/"):
        return "release-asset"
    if tail.startswith("raw/") or tail.startswith("refs/heads/") or "/raw/" in tail:
        return "raw-file"
    if tail.startswith("archive/") or tail.endswith(".tar.gz") or tail.endswith(".zip"):
        return "archive"
    return "github-url-fetch"


def derivation_blocks(text: str, rel_path: str) -> Iterable[tuple[str, str]]:
    found = False
    for match in DERIVATION_RE.finditer(text):
        brace = text.find("{", match.start())
        end = find_matching_brace(text, brace)
        if end is None:
            continue
        found = True
        unit_name = match.group(1) or Path(rel_path).parent.name
        yield unit_name, text[brace : end + 1]
    # Fallback for package files using uncommon helper functions.
    if not found and "github" in text:
        yield Path(rel_path).parent.name, text


def derivation_ranges(text: str) -> list[tuple[int, int]]:
    """Return ranges for derivation-like blocks in a Nix file.

    Some packages, notably pkgs/hermes-agent/package.nix, define `src =
    fetchFromGitHub { ... };` in a top-level `let` and then `inherit src` into
    one or more derivations. The normal derivation-block scanner misses those
    source fetches, so we separately scan fetches that are outside these ranges.
    """
    ranges: list[tuple[int, int]] = []
    for match in DERIVATION_RE.finditer(text):
        brace = text.find("{", match.start())
        end = find_matching_brace(text, brace)
        if end is not None:
            ranges.append((match.start(), end + 1))
    return ranges


def in_any_range(pos: int, ranges: list[tuple[int, int]]) -> bool:
    return any(start <= pos < end for start, end in ranges)


def file_fingerprint(root: Path) -> str:
    h = hashlib.sha256()
    for path in sorted(root.rglob("*.nix")):
        rel = path.relative_to(root)
        if path.name == "flake.nix":
            continue
        data = path.read_bytes()
        h.update(str(rel).encode())
        h.update(b"\0")
        h.update(hashlib.sha256(data).digest())
    h.update(str(SCANNER_VERSION).encode())
    return h.hexdigest()


def scan_inventory(root: Path) -> list[FetchItem]:
    items: list[FetchItem] = []
    for path in sorted(root.rglob("*.nix")):
        rel = str(path.relative_to(root))
        if path.name == "flake.nix":
            continue
        text = path.read_text(errors="ignore")
        if "github" not in text and "fetchFromGitHub" not in text:
            continue
        for unit_name, block in derivation_blocks(text, rel):
            if "github" not in block and "fetchFromGitHub" not in block:
                continue
            ctx = attrs_ctx(block)
            package = ctx.get("pname") or ctx.get("name") or unit_name

            for m in re.finditer(r"fetchFromGitHub\s*\{", block):
                brace = block.find("{", m.start())
                end = find_matching_brace(block, brace)
                if end is None:
                    continue
                fblock = block[brace : end + 1]
                owner = get_attr(fblock, "owner", ctx)
                repo = get_attr(fblock, "repo", ctx)
                rev = get_attr(fblock, "rev", ctx)
                if not owner or not repo:
                    continue
                track_branch = find_track_branch(block, m.start())
                current = ctx.get("version")
                if rev and "${version}" not in rev and parse_version(rev):
                    current = rev
                elif rev and track_branch:
                    # SHA-pinned, branch-tracked: compare old vs new SHA.
                    current = rev
                pinned = (rel, owner, repo) in PINNED_FETCHES
                items.append(FetchItem(package, rel, "fetchFromGitHub", "source", owner, repo, current, rev, pinned, track_branch))

            for m in re.finditer(rf"\b(?:pkgs\.)?{FETCH_FUNCS}\s*\{{", block):
                brace = block.find("{", m.start())
                end = find_matching_brace(block, brace)
                if end is None:
                    continue
                fblock = block[brace : end + 1]
                if "github" not in fblock:
                    continue
                url = get_attr(fblock, "url", ctx) or ""
                gm = GITHUB_URL_RE.search(url) or GITHUB_URL_RE.search(fblock)
                if not gm:
                    continue
                owner, repo, tail = gm.group(1), gm.group(2), gm.group(3) or ""
                current = ctx.get("version")
                # If the package version is intentionally generic, infer from the release/tag URL when present.
                mm = re.search(r"/download/([^/]+)/", url) or re.search(r"/refs/tags/([^/]+)/", url)
                if (not current or current == "latest") and mm:
                    current = eval_simple('"' + mm.group(1) + '"', ctx)
                pinned = (rel, owner, repo) in PINNED_FETCHES
                items.append(
                    FetchItem(
                        package,
                        rel,
                        "fetchurl-github",
                        source_kind_from_url_tail(tail),
                        owner,
                        repo,
                        current,
                        url or "(github URL in fetch block)",
                        pinned,
                    )
                )

        # Also catch top-level/shared source fetches such as:
        #   let
        #     version = "...";
        #     src = fetchFromGitHub { ... };
        #   in stdenv.mkDerivation { inherit version src; ... }
        # These sit outside the derivation blocks above and previously caused
        # pkgs/hermes-agent/package.nix to be invisible to the daily report.
        ranges = derivation_ranges(text)
        top_text_parts: list[str] = []
        last = 0
        for start, end in ranges:
            top_text_parts.append(text[last:start])
            last = end
        top_text_parts.append(text[last:])
        top_text = "\n".join(top_text_parts)
        top_ctx = attrs_ctx(top_text)
        top_package = top_ctx.get("pname") or top_ctx.get("name") or Path(rel).parent.name
        for m in re.finditer(r"fetchFromGitHub\s*\{", text):
            if in_any_range(m.start(), ranges):
                continue
            brace = text.find("{", m.start())
            end = find_matching_brace(text, brace)
            if end is None:
                continue
            fblock = text[brace : end + 1]
            owner = get_attr(fblock, "owner", top_ctx)
            repo = get_attr(fblock, "repo", top_ctx)
            rev = get_attr(fblock, "rev", top_ctx)
            if not owner or not repo:
                continue
            track_branch = find_track_branch(text, m.start())
            # Prefer the let-binding identifier (e.g. `gsd-repo = fetchFromGitHub`)
            # so multiple top-level fetches in one file get distinct package keys —
            # otherwise they all collapse to the parent dir name and the
            # exactly-one-match guard in apply_auto_update bails.
            bind = re.search(r"([A-Za-z_][\w-]*)\s*=\s*(?:pkgs\.)?\s*$", text[max(0, m.start() - 80) : m.start()])
            fetch_package = bind.group(1) if bind else top_package
            current = top_ctx.get("version")
            if rev and "${version}" not in rev and parse_version(rev):
                current = rev
            elif rev and track_branch:
                # SHA-pinned, branch-tracked: compare old vs new SHA.
                current = rev
            pinned = (rel, owner, repo) in PINNED_FETCHES
            items.append(FetchItem(fetch_package, rel, "fetchFromGitHub", "source", owner, repo, current, rev, pinned, track_branch))

    # Dedup by fetch content rather than package name. A file with no real
    # derivation is scanned twice — once via the whole-file fallback block in
    # derivation_blocks (which names the item after a `name = "..."` attr) and
    # once via the top-level loop (which names it after the let-binding). Key on
    # the source identity and keep the entry with a clean Nix-identifier name.
    def is_clean_name(name: str | None) -> bool:
        return bool(re.fullmatch(r"[A-Za-z_][A-Za-z0-9_-]*", name or ""))

    chosen: dict[tuple, FetchItem] = {}
    order: list[tuple] = []
    for item in items:
        key = (item.kind, item.path, item.source_kind, item.owner.lower(), item.repo.lower(), item.rev_or_url)
        if key not in chosen:
            chosen[key] = item
            order.append(key)
        elif is_clean_name(item.package) and not is_clean_name(chosen[key].package):
            chosen[key] = item
    return [chosen[k] for k in order]


def load_or_scan_inventory(root: Path, cache_path: Path, no_cache: bool = False) -> list[FetchItem]:
    fingerprint = file_fingerprint(root)
    if not no_cache and cache_path.exists():
        try:
            cache = json.loads(cache_path.read_text())
            if cache.get("scanner_version") == SCANNER_VERSION and cache.get("fingerprint") == fingerprint:
                return [FetchItem(**item) for item in cache.get("items", [])]
        except Exception:
            pass

    items = scan_inventory(root)
    cache_path.parent.mkdir(parents=True, exist_ok=True)
    cache_path.write_text(
        json.dumps(
            {
                "scanner_version": SCANNER_VERSION,
                "root": str(root),
                "fingerprint": fingerprint,
                "generated_at": int(time.time()),
                "items": [asdict(item) for item in items],
            },
            indent=2,
        )
        + "\n"
    )
    return items


def latest_tags(owner: str, repo: str) -> tuple[list[str], str | None]:
    url = f"https://github.com/{owner}/{repo}.git"
    try:
        output = run(["git", "ls-remote", "--tags", "--refs", url], timeout=40)
    except subprocess.CalledProcessError as exc:
        return [], (exc.output.strip().splitlines()[-1] if exc.output else f"exit {exc.returncode}")
    except Exception as exc:
        return [], f"{type(exc).__name__}: {exc}"

    tags: list[str] = []
    for line in output.splitlines():
        if "refs/tags/" not in line:
            continue
        tag = line.rsplit("refs/tags/", 1)[1]
        parsed = parse_version(tag)
        if parsed and not parsed[1]:
            tags.append(tag)
    def tag_sort_key(tag: str):
        parsed = parse_version(tag)
        nums = parsed[0] if parsed else ()
        # Prefer canonical tags like v1.2.3 / 1.2.3 over platform-prefixed aliases
        # such as mac-v1.2.3 when both point at the same version.
        canonical = 1 if re.match(r"^v?\d", tag) else 0
        return nums, canonical

    tags = sorted(set(tags), key=tag_sort_key, reverse=True)
    return tags, None


def latest_branch_head(owner: str, repo: str, branch: str) -> tuple[str | None, str | None]:
    """Resolve the current HEAD SHA of a branch via `git ls-remote`."""
    url = f"https://github.com/{owner}/{repo}.git"
    try:
        output = run(["git", "ls-remote", url, f"refs/heads/{branch}"], timeout=40)
    except subprocess.CalledProcessError as exc:
        return None, (exc.output.strip().splitlines()[-1] if exc.output else f"exit {exc.returncode}")
    except Exception as exc:
        return None, f"{type(exc).__name__}: {exc}"
    line = output.strip().splitlines()[0] if output.strip() else ""
    sha = line.split("\t", 1)[0].split()[0] if line else ""
    if not re.fullmatch(r"[0-9a-f]{40}", sha):
        return None, f"could not resolve refs/heads/{branch}"
    return sha, None


def build_report(items: list[FetchItem]) -> list[ReportItem]:
    reports: list[ReportItem] = []
    tag_cache: dict[tuple[str, str], tuple[list[str], str | None]] = {}
    for item in items:
        report = ReportItem(**asdict(item))
        if item.pinned:
            report.status = "pinned"
            reports.append(report)
            continue
        if item.track_branch:
            sha, error = latest_branch_head(item.owner, item.repo, item.track_branch)
            report.latest = sha
            report.latest_error = error
            report.latest_url = (
                f"https://github.com/{item.owner}/{item.repo}/commit/{sha}" if sha else None
            )
            report.current_normalised = item.rev_or_url
            report.latest_normalised = sha
            if sha and item.rev_or_url and sha != item.rev_or_url:
                report.status = "update"
            elif sha and sha == item.rev_or_url:
                report.status = "ok"
            else:
                report.status = "unknown"
            reports.append(report)
            continue
        key = (item.owner, item.repo)
        if key not in tag_cache:
            tag_cache[key] = latest_tags(item.owner, item.repo)
        tags, error = tag_cache[key]
        latest = tags[0] if tags else None
        report.latest = latest
        report.latest_url = f"https://github.com/{item.owner}/{item.repo}/releases/tag/{latest}" if latest else None
        report.latest_error = error
        report.tag_count = len(tags)
        report.current_normalised = normalise_version(item.current)
        report.latest_normalised = normalise_version(latest)
        newer = is_newer(latest, item.current) if latest and item.current else None
        if newer is True:
            report.status = "update"
        elif newer is False:
            report.status = "ok"
        else:
            report.status = "unknown"
        reports.append(report)
    return reports


def unique_reports(reports: list[ReportItem]) -> list[ReportItem]:
    unique: list[ReportItem] = []
    seen = set()
    for row in reports:
        key = (row.package, row.owner.lower(), row.repo.lower(), row.source_kind, row.current, row.latest, row.path)
        if key in seen:
            continue
        seen.add(key)
        unique.append(row)
    return unique


def markdown_report(
    root: Path,
    reports: list[ReportItem],
    include_ok: bool = False,
    include_unknown: bool = True,
    total_discovered: int | None = None,
) -> str:
    counts = {status: sum(1 for r in reports if r.status == status) for status in ["update", "ok", "unknown", "pinned"]}
    total = total_discovered if total_discovered is not None else len(reports)
    header_count = (
        f"Reported GitHub package/source fetches: **{len(reports)}** · Total discovered: **{total}**"
        if total_discovered is not None and total_discovered != len(reports)
        else f"Scanned GitHub package/source fetches: **{len(reports)}**"
    )
    lines = [
        "# Nix GitHub package update report",
        "",
        f"Repo: `{root}`",
        header_count,
        f"Updates: **{counts['update']}** · OK: **{counts['ok']}** · Unknown: **{counts['unknown']}** · Pinned: **{counts['pinned']}**",
        "",
    ]

    def table(title: str, rows: list[ReportItem]) -> None:
        lines.append(f"## {title}")
        lines.append("")
        unique_rows = unique_reports(rows)
        if not unique_rows:
            lines.append("None.")
            lines.append("")
            return
        lines.append("| Package | Source | Current | Latest | Path |")
        lines.append("|---|---|---:|---:|---|")
        for r in unique_rows:
            latest = r.latest or "—"
            if r.latest_url and r.latest:
                latest = f"[{r.latest}]({r.latest_url})"
            lines.append(
                f"| `{r.package}` | `{r.owner}/{r.repo}` `{r.source_kind}` | `{r.current or '—'}` | {latest} | `{r.path}` |"
            )
        lines.append("")

    table("Likely updates", [r for r in reports if r.status == "update"])
    table("Pinned / intentionally ignored", [r for r in reports if r.status == "pinned"])
    if include_ok:
        table("Current", [r for r in reports if r.status == "ok"])
    if include_unknown:
        table("Unknown / needs custom strategy", [r for r in reports if r.status == "unknown"])
    return "\n".join(lines).rstrip() + "\n"


def prefetch_github(owner: str, repo: str, tag: str, root: Path) -> tuple[str | None, str]:
    code, output = run_result(["nix", "flake", "prefetch", f"github:{owner}/{repo}/{tag}", "--json"], cwd=root, timeout=180)
    if code != 0:
        return None, output
    try:
        data = json.loads(output[output.find("{"):])
        return data.get("hash"), output
    except Exception as exc:
        return None, output + f"\nFailed to parse prefetch JSON: {exc}"


def prefetch_file(url: str, root: Path) -> tuple[str | None, str]:
    code, output = run_result(["nix", "store", "prefetch-file", "--json", "--hash-type", "sha256", url], cwd=root, timeout=240)
    if code != 0:
        return None, output
    try:
        data = json.loads(output[output.find("{"):])
        return data.get("hash"), output
    except Exception as exc:
        return None, output + f"\nFailed to parse prefetch JSON: {exc}"


def replace_unique(text: str, pattern: str, replacement: str, label: str) -> tuple[str, str | None]:
    new_text, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        return text, f"Could not replace unique {label}"
    return new_text, None


def has_attr(text: str, attr: str) -> bool:
    return re.search(rf'\b{re.escape(attr)}\s*=\s*"[^"]*"\s*;', text) is not None


def replace_attr_hash(text: str, attr: str, value: str) -> tuple[str, str | None]:
    return replace_unique(text, rf'(\b{re.escape(attr)}\s*=\s*")([^"]+)("\s*;)', rf'\g<1>{value}\g<3>', attr)


def replace_first_source_hash(text: str, value: str) -> tuple[str, str | None]:
    return replace_unique(text, r'(\b(?:hash|sha256)\s*=\s*")sha256-[^"]+("\s*;)', rf'\g<1>{value}\g<2>', "source hash/sha256")




def replace_version_for_item(text: str, item: ReportItem, new_version: str) -> tuple[str, str | None]:
    pname_pat = rf'(pname\s*=\s*"{re.escape(item.package)}"\s*;)(.*?)(\bversion\s*=\s*")([^"]+)("\s*;)'
    new_text, count = re.subn(pname_pat, rf'\g<1>\g<2>\g<3>{new_version}\g<5>', text, count=1, flags=re.S)
    if count == 1:
        return new_text, None
    # Some inline sources are not derivations and have no version attr; skip rather than corrupting another package.
    return text, None


def replace_hash_after_anchor(text: str, anchor: str, value: str, label: str) -> tuple[str, str | None]:
    idx = text.find(anchor)
    if idx < 0:
        return text, f"Could not find anchor for {label}"
    end = text.find("};", idx)
    if end < 0:
        end = min(len(text), idx + 1200)
    segment = text[idx:end]
    new_segment, count = re.subn(r'(\b(?:hash|sha256)\s*=\s*")sha256-[^"]+("\s*;)', rf'\g<1>{value}\g<2>', segment, count=1, flags=re.S)
    if count != 1:
        return text, f"Could not replace hash for {label}"
    return text[:idx] + new_segment + text[end:], None


def replace_rev_after_anchor(text: str, anchor: str, old_rev: str | None, new_rev: str) -> tuple[str, str | None]:
    idx = text.find(anchor)
    if idx < 0:
        return text, "Could not find anchor for rev"
    end = text.find("};", idx)
    if end < 0:
        end = min(len(text), idx + 1200)
    segment = text[idx:end]
    if "${version}" in segment:
        return text, None
    if old_rev:
        new_segment, count = re.subn(r'(\brev\s*=\s*")' + re.escape(old_rev) + r'("\s*;)', rf'\g<1>{new_rev}\g<2>', segment, count=1, flags=re.S)
    else:
        new_segment, count = re.subn(r'(\brev\s*=\s*")([^"]+)("\s*;)', rf'\g<1>{new_rev}\g<3>', segment, count=1, flags=re.S)
    if count != 1:
        return text, "Could not replace rev near anchor"
    return text[:idx] + new_segment + text[end:], None


def replace_url_exact(text: str, old_url: str, new_url: str) -> tuple[str, str | None]:
    return replace_unique(text, r'(\burl\s*=\s*")' + re.escape(old_url) + r'("\s*;)', rf'\g<1>{new_url}\g<2>', "url")

def infer_latest_url(item: ReportItem) -> str | None:
    url = item.rev_or_url or ""
    if not item.latest or not item.latest_normalised:
        return None
    latest = item.latest
    latest_norm = item.latest_normalised
    current = item.current or ""
    current_norm = item.current_normalised or normalise_version(current) or ""

    replacements: list[tuple[str, str]] = []
    if current_norm:
        replacements.append(("v" + current_norm, latest))
        replacements.append((current_norm, latest_norm))
    if current:
        replacements.append((current, latest if current.startswith("v") else latest_norm))
    # Raw branch files are often tracked by a package version; switch to a tag ref.
    replacements.append(("/raw/refs/heads/main/", f"/raw/refs/tags/{latest}/"))
    replacements.append(("/raw/main/", f"/raw/{latest}/"))
    replacements.append(("/main/", f"/{latest}/"))

    new_url = url
    for old, new in replacements:
        if old and old in new_url:
            new_url = new_url.replace(old, new)

    # Known upstream rename: adPEAS-Light.ps1 was replaced by the obfuscated light script.
    if item.owner == "61106960" and item.repo == "adPEAS" and item.package == "adPEAS-Light":
        new_url = new_url.replace("/adPEAS-Light.ps1", "/adPEAS_obf.ps1")

    return new_url if new_url != url else None


def build_command_for_item(root: Path, item: ReportItem) -> list[str] | None:
    if item.path.startswith("pkgs/") and item.path.endswith("/package.nix"):
        pkg_text = (root / item.path).read_text(errors="ignore")
        extra_args = ""
        if re.search(r"(?m)^\s*donut\s*,", pkg_text):
            extra_args = "donut = pkgs.callPackage ./pkgs/donut/package.nix {};"
        return [
            "nix",
            "build",
            "--impure",
            "--expr",
            f"let pkgs = import <nixpkgs> {{}}; in pkgs.callPackage ./{item.path} {{ {extra_args} }}",
            "--no-link",
            "--print-out-paths",
        ]
    return None


def parse_hash_mismatch(output: str, attr: str | None = None) -> str | None:
    # Nix commonly prints either "got: sha256-..." or "specified: ... got: ...".
    matches = re.findall(r"got:\s+(sha256-[A-Za-z0-9+/=]+)", output)
    if matches:
        return matches[-1]
    matches = re.findall(r"\b(sha256-[A-Za-z0-9+/=]{20,})", output)
    # Avoid returning the fake hash if it is the only one found.
    fake = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    for m in reversed(matches):
        if m != fake:
            return m
    return None


def build_with_dependency_hash_retries(root: Path, path: Path, item: ReportItem, build_cmd: list[str], max_rounds: int = 4) -> tuple[bool, str, list[dict[str, str]]]:
    dep_attrs = ["vendorHash", "cargoHash", "npmDepsHash", "pnpmDepsHash", "yarnHash"]
    fake = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    adjustments: list[dict[str, str]] = []
    output_accum: list[str] = []

    for _round in range(max_rounds):
        code, output = run_result(build_cmd, cwd=root, timeout=600)
        output_accum.append(output)
        if code == 0:
            return True, output.strip(), adjustments

        text = path.read_text()
        changed = False
        # Prefer replacing an existing dependency hash with the fake hash to force Nix to reveal the correct one.
        for attr in dep_attrs:
            m = re.search(rf'\b{re.escape(attr)}\s*=\s*"([^"]+)"\s*;', text)
            if has_attr(text, attr) and m and fake not in m.group(1):
                text2, err = replace_attr_hash(text, attr, fake)
                if not err:
                    path.write_text(text2)
                    adjustments.append({"attr": attr, "action": "set_fake"})
                    changed = True
                    break
        if changed:
            continue

        got = parse_hash_mismatch(output)
        if got:
            for attr in dep_attrs:
                if has_attr(text, attr) and re.search(rf"\b{re.escape(attr)}\s*=\s*\"{re.escape(fake)}\"\s*;", text):
                    text2, err = replace_attr_hash(text, attr, got)
                    if not err:
                        path.write_text(text2)
                        adjustments.append({"attr": attr, "action": "set_actual", "hash": got})
                        changed = True
                        break
        if not changed:
            return False, "\n--- build attempt ---\n".join(output_accum)[-12000:], adjustments

    code, output = run_result(build_cmd, cwd=root, timeout=600)
    output_accum.append(output)
    return code == 0, (output.strip() if code == 0 else "\n--- build attempt ---\n".join(output_accum)[-12000:]), adjustments


def apply_source_update_text(original: str, item: ReportItem, new_hash: str) -> tuple[str | None, dict[str, Any] | None]:
    updated = original
    new_version = item.latest_normalised
    if not new_version or not item.latest:
        return None, {"error": "No comparable latest tag", "item": asdict(item)}
    updated, err = replace_version_for_item(updated, item, new_version)
    if err:
        return None, {"error": err, "item": asdict(item)}
    anchor = f'repo = "{item.repo}";'
    updated, err = replace_rev_after_anchor(updated, anchor, item.rev_or_url, item.latest)
    if err:
        return None, {"error": err, "item": asdict(item)}
    updated, err = replace_hash_after_anchor(updated, anchor, new_hash, "source hash")
    if err:
        return None, {"error": err, "item": asdict(item)}
    return updated, None


def apply_fetchurl_update_text(original: str, item: ReportItem, new_url: str, new_hash: str) -> tuple[str | None, dict[str, Any] | None]:
    updated = original
    new_version = item.latest if (item.current or "").startswith("v") else item.latest_normalised
    if not new_version:
        return None, {"error": "No comparable latest version", "item": asdict(item)}
    updated, err = replace_version_for_item(updated, item, new_version)
    if err:
        return None, {"error": err, "item": asdict(item)}
    if item.rev_or_url:
        updated, err = replace_url_exact(updated, item.rev_or_url, new_url)
    else:
        updated, err = replace_unique(updated, r'(\burl\s*=\s*")([^"]+)("\s*;)', rf'\g<1>{new_url}\g<3>', "url")
    if err:
        return None, {"error": err, "item": asdict(item), "new_url": new_url}
    updated, err = replace_hash_after_anchor(updated, new_url, new_hash, "fetchurl hash")
    if err:
        return None, {"error": err, "item": asdict(item)}
    return updated, None


def apply_auto_update(root: Path, reports: list[ReportItem], package: str, *, dry_run: bool, keep_failed: bool) -> dict[str, Any]:
    matches = [r for r in reports if r.status == "update" and r.package == package]
    if not matches:
        matches = [r for r in reports if r.status == "update" and r.path == package]
    if len(matches) != 1:
        return {"ok": False, "error": f"Expected exactly one outdated match for {package!r}, found {len(matches)}", "matches": [asdict(m) for m in matches]}
    item = matches[0]
    if item.pinned:
        return {"ok": False, "error": "Refusing to update pinned item", "item": asdict(item)}
    if not item.latest or not item.latest_normalised:
        return {"ok": False, "error": "No comparable latest tag", "item": asdict(item)}

    path = root / item.path
    original = path.read_text()
    new_hash = None
    new_url = None
    prefetch_output = ""

    if item.kind == "fetchFromGitHub" and item.source_kind == "source":
        new_hash, prefetch_output = prefetch_github(item.owner, item.repo, item.latest, root)
        if not new_hash:
            return {"ok": False, "error": "Source prefetch failed", "item": asdict(item), "prefetch_output": prefetch_output[-4000:]}
        updated, err_result = apply_source_update_text(original, item, new_hash)
    elif item.kind == "fetchurl-github" and item.source_kind in {"release-asset", "raw-file"}:
        new_url = infer_latest_url(item)
        if not new_url:
            return {"ok": False, "error": "Could not infer latest URL", "item": asdict(item)}
        new_hash, prefetch_output = prefetch_file(new_url, root)
        if not new_hash:
            return {"ok": False, "error": "File prefetch failed", "item": asdict(item), "new_url": new_url, "prefetch_output": prefetch_output[-4000:]}
        updated, err_result = apply_fetchurl_update_text(original, item, new_url, new_hash)
    else:
        return {"ok": False, "error": "Unsupported auto-update kind/source_kind", "item": asdict(item)}

    if err_result:
        return {"ok": False, **err_result}
    assert updated is not None

    build_cmd = build_command_for_item(root, item)
    result_base = {
        "item": asdict(item),
        "new_version": item.latest_normalised,
        "new_rev": item.latest,
        "new_hash": new_hash,
        "new_url": new_url,
        "would_change": original != updated,
        "build_supported": build_cmd is not None,
    }
    if dry_run:
        return {"ok": True, "dry_run": True, **result_base}

    backup = path.with_suffix(path.suffix + ".auto-update.bak")
    backup.write_text(original)
    path.write_text(updated)

    if build_cmd is None:
        backup.unlink(missing_ok=True)
        return {
            "ok": True,
            "dry_run": False,
            **result_base,
            "verification": "prefetch-only; no narrow package build available for non-pkgs path",
        }

    ok, build_output, dep_adjustments = build_with_dependency_hash_retries(root, path, item, build_cmd)
    if not ok:
        if not keep_failed:
            path.write_text(original)
        backup.unlink(missing_ok=True)
        return {
            "ok": False,
            "error": "Build failed" + ("; file left edited" if keep_failed else "; file rolled back"),
            **result_base,
            "build_command": " ".join(build_cmd),
            "dependency_hash_adjustments": dep_adjustments,
            "build_output": build_output[-12000:],
            "rolled_back": not keep_failed,
        }
    backup.unlink(missing_ok=True)
    return {
        "ok": True,
        "dry_run": False,
        **result_base,
        "build_command": " ".join(build_cmd),
        "dependency_hash_adjustments": dep_adjustments,
        "build_output": build_output.strip(),
    }

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".", help="Nix repo root")
    parser.add_argument("--cache", default=DEFAULT_CACHE, help="Generated cache path, relative to root unless absolute")
    parser.add_argument("--no-cache", action="store_true", help="Force inventory rescan")
    parser.add_argument("--format", choices=["markdown", "json"], default="markdown")
    parser.add_argument("--include-ok", action="store_true")
    parser.add_argument("--hide-unknown", action="store_true")
    parser.add_argument("--updates-only", action="store_true", help="Only print when updates exist; exit 0 silently otherwise")
    parser.add_argument("--auto-update", metavar="PACKAGE_OR_PATH", help="Experimental: update one GitHub package/source and verify when possible")
    parser.add_argument("--auto-update-all", action="store_true", help="Experimental: try every currently detected update once; never commits or switches")
    parser.add_argument("--dry-run", action="store_true", help="With --auto-update, show intended edit without writing/building")
    parser.add_argument("--keep-failed", action="store_true", help="With --auto-update, keep edits if the build fails instead of rolling back")
    args = parser.parse_args()

    root = Path(args.root).expanduser().resolve()
    cache_path = Path(args.cache)
    if not cache_path.is_absolute():
        cache_path = root / cache_path

    items = load_or_scan_inventory(root, cache_path, args.no_cache)
    reports = build_report(items)

    if args.auto_update:
        result = apply_auto_update(root, reports, args.auto_update, dry_run=args.dry_run, keep_failed=args.keep_failed)
        print(json.dumps(result, indent=2))
        return 0 if result.get("ok") else 1

    if args.auto_update_all:
        results = []
        attempted = set()
        for report in [r for r in reports if r.status == "update"]:
            key = report.package
            if key in attempted:
                continue
            attempted.add(key)
            # Recompute before each package so successful earlier updates are not retried.
            current_reports = build_report(load_or_scan_inventory(root, cache_path, True))
            if not any(r.status == "update" and r.package == key for r in current_reports):
                continue
            result = apply_auto_update(root, current_reports, key, dry_run=args.dry_run, keep_failed=args.keep_failed)
            results.append(result)
        ok_count = sum(1 for r in results if r.get("ok"))
        print(json.dumps({"ok": all(r.get("ok") for r in results), "attempted": len(results), "succeeded": ok_count, "failed": len(results) - ok_count, "results": results}, indent=2))
        return 0 if results and all(r.get("ok") for r in results) else 1

    updates = [r for r in reports if r.status == "update"]
    if args.updates_only and not updates:
        return 0

    if args.format == "json":
        print(json.dumps({"root": str(root), "count": len(reports), "items": [asdict(r) for r in reports]}, indent=2))
    else:
        include_unknown = not args.hide_unknown
        total_discovered = None
        if args.updates_only:
            total_discovered = len(reports)
            reports = [r for r in reports if r.status in {"update", "pinned"}]
            include_unknown = False
        print(markdown_report(root, reports, include_ok=args.include_ok, include_unknown=include_unknown, total_discovered=total_discovered))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
