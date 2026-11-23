---
paths:
  - "overlays/**"
  - "patches/**"
---

# Editing upstream source in an overlay

Applies to any overlay that changes a dependency's own files — today that is
`overlays/serpantinum.nix`, whose QML the top bar is built from.

Carry the change as an **edit over the upstream source**, never as a copied
whole file. A copy goes stale silently and ships a widget frozen at whatever
upstream looked like the day it was copied; an edit that no longer applies
fails the build loudly.

Two forms. Pick by what the edit does:

| The edit | Form | Lives in |
| --- | --- | --- |
| Swaps one token — a colour role, a pixel constant, an icon glyph | `substituteInPlace --replace-fail` | `postPatch` in the overlay |
| Adds, removes or moves lines | `.patch` file | `patches/<pkg>/NNNN-name.patch` |
| A whole new file we author, that upstream does not have | real file + `install -D` | `patches/<pkg>/files/<path>` |

The third row is the exception that proves the first two. A diff earns its keep
by breaking loudly when upstream moves the code around it — a file upstream
does not have has no such context, so storing it as a patch buys nothing and
makes it unreadable and uneditable. Keep it as a real file, `install -D` it from
`postPatch`, and use a small `.patch` for the handful of upstream lines that
wire it in. `overlays/serpantinum.nix` does this for the system monitor panel
and the LocalSend backend.

A unified diff pins three context lines either side of its change, so an
unrelated upstream edit *near* the target breaks it. `--replace-fail` keys off
the target string alone and breaks only when that string itself changes. Most
theming tweaks are one-token, so most belong in `postPatch`.

**Confirm the target string occurs exactly once in the file before adding a
`--replace-fail`.** `substituteInPlace` rewrites every occurrence, so a
repeated string silently changes lines you did not mean to touch — the one
failure mode here that does not announce itself. When it is not unique, use a
`.patch` file.

## Generating a patch

Patches apply in list order, and each one's context lines must match the file
*after* the earlier patches ran. So generate against a tree that already has
them:

```sh
src=$(nix eval --raw --impure --expr \
  '(builtins.getFlake (toString /home/hailst0rm/.nixos)).nixosConfigurations.<host>.pkgs.<pkg>.src.outPath')
cp -r --no-preserve=mode "$src" /tmp/w/before
for p in patches/<pkg>/*.patch; do patch -d /tmp/w/before -p1 -i "$p"; done
cp -r --no-preserve=mode /tmp/w/before /tmp/w/after   # edit files under after/
diff -u /tmp/w/before/<file> /tmp/w/after/<file> \
  | sed 's|^--- /tmp/w/before/|--- a/|; s|^+++ /tmp/w/after/|+++ b/|'
```

Numbers order the sequence; they are not identities. Gaps are fine — `0007`
does not exist.

Glyph edits carry non-ASCII codepoints that a shell heredoc will silently
strip. Write them from Python with `chr(0xF1105)` rather than pasting the
character, then read the bytes back with `cat -v` to confirm they landed.

## Proving a refactor changed nothing

Moving an edit between the two forms, or renumbering patches, must leave the
built output identical. Build the derivation before and after, then diff the
payload directory:

```sh
diff -r /nix/store/<old>-<pkg>/share/<pkg> /nix/store/<new>-<pkg>/share/<pkg>
```

Wrapper scripts under `bin/` always differ by their own store path; the payload
directory is the one that must match byte for byte.
