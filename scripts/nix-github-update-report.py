#!/usr/bin/env python3
"""Report outdated GitHub-sourced Nix package fetches.

This intentionally treats the Nix repo as the source of truth:
- no manually maintained package watchlist
- flake inputs are ignored
- package/source fetch inventory is generated and cached automatically

It detects GitHub sources in derivation-like blocks using:
- fetchFromGitHub
- fetchurl/fetchzip/fetchTarball/fetchgit with GitHub URLs

The report is read-only: it does not update packages, hashes, branches, or commits.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
import time
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Iterable

SCANNER_VERSION = 1
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
                current = ctx.get("version")
                if rev and "${version}" not in rev and parse_version(rev):
                    current = rev
                pinned = (rel, owner, repo) in PINNED_FETCHES
                items.append(FetchItem(package, rel, "fetchFromGitHub", "source", owner, repo, current, rev, pinned))

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

    deduped: list[FetchItem] = []
    seen = set()
    for item in items:
        key = (item.kind, item.path, item.package, item.owner.lower(), item.repo.lower(), item.rev_or_url)
        if key in seen:
            continue
        seen.add(key)
        deduped.append(item)
    return deduped


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


def build_report(items: list[FetchItem]) -> list[ReportItem]:
    reports: list[ReportItem] = []
    tag_cache: dict[tuple[str, str], tuple[list[str], str | None]] = {}
    for item in items:
        report = ReportItem(**asdict(item))
        if item.pinned:
            report.status = "pinned"
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


def markdown_report(root: Path, reports: list[ReportItem], include_ok: bool = False, include_unknown: bool = True) -> str:
    counts = {status: sum(1 for r in reports if r.status == status) for status in ["update", "ok", "unknown", "pinned"]}
    lines = [
        "# Nix GitHub package update report",
        "",
        f"Repo: `{root}`",
        f"Scanned GitHub package/source fetches: **{len(reports)}**",
        f"Updates: **{counts['update']}** · OK: **{counts['ok']}** · Unknown: **{counts['unknown']}** · Pinned: **{counts['pinned']}**",
        "",
    ]

    def table(title: str, rows: list[ReportItem], columns: list[str]) -> None:
        lines.append(f"## {title}")
        lines.append("")
        unique_rows: list[ReportItem] = []
        seen_rows = set()
        for row in rows:
            key = (row.package, row.owner.lower(), row.repo.lower(), row.source_kind, row.current, row.latest, row.path)
            if key in seen_rows:
                continue
            seen_rows.add(key)
            unique_rows.append(row)
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

    table("Likely updates", [r for r in reports if r.status == "update"], [])
    table("Pinned / intentionally ignored", [r for r in reports if r.status == "pinned"], [])
    if include_ok:
        table("Current", [r for r in reports if r.status == "ok"], [])
    if include_unknown:
        table("Unknown / needs custom strategy", [r for r in reports if r.status == "unknown"], [])
    return "\n".join(lines).rstrip() + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", default=".", help="Nix repo root")
    parser.add_argument("--cache", default=DEFAULT_CACHE, help="Generated cache path, relative to root unless absolute")
    parser.add_argument("--no-cache", action="store_true", help="Force inventory rescan")
    parser.add_argument("--format", choices=["markdown", "json"], default="markdown")
    parser.add_argument("--include-ok", action="store_true")
    parser.add_argument("--hide-unknown", action="store_true")
    parser.add_argument("--updates-only", action="store_true", help="Only print when updates exist; exit 0 silently otherwise")
    args = parser.parse_args()

    root = Path(args.root).expanduser().resolve()
    cache_path = Path(args.cache)
    if not cache_path.is_absolute():
        cache_path = root / cache_path

    items = load_or_scan_inventory(root, cache_path, args.no_cache)
    reports = build_report(items)
    updates = [r for r in reports if r.status == "update"]

    if args.updates_only and not updates:
        return 0

    if args.format == "json":
        print(json.dumps({"root": str(root), "count": len(reports), "items": [asdict(r) for r in reports]}, indent=2))
    else:
        include_unknown = not args.hide_unknown
        if args.updates_only:
            reports = [r for r in reports if r.status in {"update", "pinned"}]
            include_unknown = False
        print(markdown_report(root, reports, include_ok=args.include_ok, include_unknown=include_unknown))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
