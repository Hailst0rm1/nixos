"""Render Excalidraw JSON to PNG via agent-browser.

Usage:
    python3 ~/.claude/skills/excalidraw-diagram/references/render_excalidraw.py \
        <path-to-file.excalidraw> [--output path.png] [--scale 2]

Needs no setup: `agent-browser` drives nixpkgs chromium, and the Excalidraw
export bundle sits next to this script.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).parent
BUNDLE = HERE / "excalidraw-utils.min.js"
TEMPLATE = HERE / "render_template.html"

# A dedicated session, so renders never clobber other agent-browser work.
SESSION = "excalidraw-render"


def fail(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    sys.exit(1)


def load(path: Path) -> dict:
    """Read and validate an .excalidraw file."""
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        fail(f"invalid JSON in {path}: {e}")

    if data.get("type") != "excalidraw":
        fail(f"expected type 'excalidraw', got '{data.get('type')}'")
    if not isinstance(data.get("elements"), list):
        fail("'elements' must be an array")
    if not data["elements"]:
        fail("'elements' is empty — nothing to render")

    return data


def build_page(data: dict, scale: int) -> Path:
    """Write a self-contained HTML page with the diagram inlined."""
    if not BUNDLE.exists():
        fail(f"export bundle missing at {BUNDLE} (it is fetched by claude-code.nix)")

    # `</` would close the <script> block early, whatever the JSON contains.
    payload = json.dumps(data).replace("</", "<\\/")
    html = (
        TEMPLATE.read_text(encoding="utf-8")
        .replace("__BUNDLE__", BUNDLE.as_uri())
        .replace("__DATA__", payload)
        .replace("__SCALE__", str(scale))
    )
    page = Path(tempfile.mkdtemp(prefix="excalidraw-render-")) / "render.html"
    page.write_text(html, encoding="utf-8")
    return page


def browser(*args: str, check: bool = True) -> tuple[int, str]:
    result = subprocess.run(
        ["agent-browser", "--session", SESSION, *args],
        capture_output=True,
        text=True,
    )
    output = (result.stdout + result.stderr).strip()
    if check and result.returncode != 0:
        fail(f"agent-browser {args[0]} failed: {output}")
    return result.returncode, output


def render(source: Path, output: Path, scale: int) -> Path:
    page = build_page(load(source), scale)

    browser("open", page.as_uri())

    # The export runs async in the page. No SVG means it threw, and the page
    # title carries the reason.
    code, _ = browser("wait", "#root svg", check=False)
    if code != 0:
        _, title = browser("eval", "document.title")
        fail(f"Excalidraw export produced no SVG. Page reported: {title}")

    # An element screenshot only paints what the viewport covers, so anything
    # below the fold comes back blank. Grow the viewport to the whole diagram.
    _, dimensions = browser(
        "eval",
        "(()=>{const s=document.querySelector('#root svg');"
        "return s.getAttribute('width')+' '+s.getAttribute('height')})()",
    )
    width, height = (round(float(v)) for v in dimensions.strip('"').split())
    browser("set", "viewport", str(width), str(height))

    browser("screenshot", "#root svg", str(output))
    return output


def main() -> None:
    parser = argparse.ArgumentParser(description="Render Excalidraw JSON to PNG")
    parser.add_argument("input", type=Path, help="Path to .excalidraw JSON file")
    parser.add_argument("--output", "-o", type=Path, default=None, help="Output PNG path (default: same name with .png)")
    parser.add_argument("--scale", "-s", type=int, default=2, help="SVG scale factor (default: 2)")
    args = parser.parse_args()

    if not args.input.exists():
        fail(f"file not found: {args.input}")

    print(render(args.input, args.output or args.input.with_suffix(".png"), args.scale))


if __name__ == "__main__":
    main()
