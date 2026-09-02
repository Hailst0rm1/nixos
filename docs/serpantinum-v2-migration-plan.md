# Serpantinum v1-fork → v2.0 migration plan

**Date:** 2026-08-31 · **Companion:** `docs/serpantinum-v2-audit.md`
**Upstream:** github.com/ilyamiro/serpantinum @ v2.0.1

## Constraints

1. Keep the topbar's look — capsule pills, grouped clusters, translucency.
2. Keep Catppuccin Mocha.
3. Keep the `accentColour` option behaviour: **one accent everywhere**, not many colours.
4. No telemetry.

Constraint 4 is satisfied by construction: `nix/package.nix`'s fileset is
`bin src config compositors version.txt`, so the installer — the only place telemetry lives —
is not in the Nix build. No telemetry references exist in `src/` or `bin/`.

---

## Decision record

| # | Decision |
|---|---|
| 1 | Consume v2 as a **flake input** via `overlays.default`, so it builds against our nixpkgs 26.05. `flake.lock` pins the rev; no manual SHA needed (the AGENTS.md `rev = "main"` rule is about `fetchFromGitHub` in derivations). |
| 2 | Reproduce the topbar **via settings**, plus a **capped patch set** (below). |
| 3 | `matugen = false`, `activePreset` ≠ `"Matugen"`, and `theme.colors` generated in Nix from `importConfig.hyprland.accentColour`. |
| 4 | Pin location manually; neutralise the updater; keep Open-Meteo. Delete the sops OpenWeather secret. |
| 5 | New `serpantinum.enable` option in parallel with the v1 module. Roll out per host, **Nix-Tower first**. Delete the v1 fork only at the end. |
| 6 | `appLauncher` gains a `"serpantinum"` value, set via `lib.mkOverride 900`. |
| 7 | Keep mpvpaper/swww. v2's wallpaper engine is not adopted. |
| 8 | New `screenshot` selector (`"hyprshot"` \| `"serpantinum"`), also `mkOverride 900`. |
| 9 | Adopt idle, clipboard and blue-light filter. Keep `lxqt-policykit`; v2's polkit agent stays off. **`idle.enabled = false` by default.** |
| 10 | Patch `WorkspacesWidget` for hyprsplit rather than dropping hyprsplit. |
| 11 | Carry deltas as `.patch` files, not `postInstall` file copies. |
| 12 | `settings.json` is **overwritten on every activation** — Nix is the source of truth. |
| 13 | The Obsidian diary hook is dropped, not re-implemented. |
| 14 | serpantinum joins the normal automated flake-update sweep. |
| 15 | Bar modules: like-for-like, **plus `sysmon` and `info`**. |
| 16 | `notifications.dnd = false`, `general.muteSfx = true`. |
| 17 | `general.quickactions = true`; desktop widgets stay off. |

### Why `mkOverride 900` and not `mkForce`

The v1 module uses `lib.mkForce` on `panel`/`notifications`/`lockscreen`
(`quickshell.nix:61-72`). Because every host defaults `quickshell.ilyamiro.enable = true`,
those `mkForce`s make `hyprpanel.nix` (492 lines), `swaync.nix`, `hyprlock.nix` and
`waybar.nix` **permanently unreachable** — the selector options are decorative.

`mkOverride 900` sits between `mkDefault` (1000) and a normal definition (100). So:

- serpantinum enabled → it wins over the `mkDefault "rofi"` in `users/hailst0rm/hosts/default.nix:54-71`
- an explicit per-host `appLauncher = "rofi"` (priority 100) still wins over serpantinum

Consequence: **hyprpanel / swaync / hyprlock / waybar become live fallbacks again** instead of
dead code. Keep them; do not delete them with the v1 fork.

---

## How the three look-constraints are met

All verified against upstream source.

| Constraint | Mechanism | Evidence |
|---|---|---|
| Capsule pills | `theme.borderRadius = 20`. Widgets are `height: barWindow.barHeight`, and `barHeight = s(40)`, so 20 is exactly height/2. The `clampedBorderRadius` compression only applies above 24 and has **zero consumers in the bar**. | `WifiWidget.qml:144-145`, `Bar.qml:224`, `ThemeBackend.qml:11-18` |
| Grouped cluster in one translucent box | Nested array in `bar.modules` triggers `groupBgRepeater`: fill `Qt.alpha(base, barOpacity)`, 1px `Qt.alpha(surface0, barOpacity)` hairline border, radius `ThemeBackend.borderRadius`. Structurally identical to the local `base@0.75` + hairline. | `TopBar.qml:646-655` |
| `base @ 0.75` glass | `bar.opacity = 75`, applied per element via `Qt.alpha(...)`, not to the window. | `Bar.qml:95` |
| **One accent everywhere** | `theme.colors` is `attrsOf str` with "Any key name is accepted"; `ThemeBackend` assigns 22 named colour properties from it. Bar widgets reference those names, so collapsing the accent-role keys to one hex unifies every pill. | `settings-options.nix:71-75`, `ThemeBackend.qml:270-292` |

### ⚠️ `bar.style` must be `"modular"`

The group background carries `visible: … && !isSolid && !isFill` (`TopBar.qml:648`). Under
`solid` or `fill` the group boxes **do not render at all** and the bar becomes a continuous
strip. `modular` is the floating-translucent-pills style and the only one matching the current look.

### The accent collapse

Bar colour-role usage counts (`grep -rhoE "ThemeBackend\.[a-zA-Z0-9]+" bar/`):

- **Collapse to accent:** `mauve` (28 refs — bluetooth, volume, sysmon, weather), `blue` (4 — wifi), `teal` (3 — battery normal), `sapphire` (3 — one sysmon stat), `peach` (3)
- **Keep at Mocha values (neutrals):** `base`, `mantle`, `crust`, `surface0-2`, `text`, `subtext0/1`, `overlay0-2`
- **Keep at Mocha values (semantic):** `red`, `green` — see below

### Semantic vs decorative red/green

Both categories read the same `ThemeBackend.red` / `.green` keys, so **settings cannot separate
them**. Hence patches 2-4.

*Functional — must keep meaning:* `BatWidget.qml:29-31` (red ≤15%, green charging) ·
`BatWidget.qml:203` (red on desktop) · `InfoWidget.qml:241,258` (red recording dot) ·
`SideBatWidget.qml:79` · `SideInfoWidget.qml:29` (timer state)

*Decorative — should follow the accent:* `SysMonWidget.qml:266` (temperature pill is statically
red; the CPU pill beside it is statically sapphire) · `MediaWidget.qml:255` and
`SideMediaWidget.qml:202` (play/pause turns green **on hover**)

---

## The patch set — hard cap: 5 patches / 6 files

Carried as `.patch` files under `patches/serpantinum/`, applied via `overrideAttrs`.
Patches fail the build loudly when upstream drifts; whole-file copies would silently ship
stale widgets forever.

| # | File | Change | Why settings can't do it |
|---|---|---|---|
| 1 | `src/quickshell/reusables/ClickButton.qml` | Restore the 2-stop horizontal gradient, accent → `Qt.lighter(accent, 1.3)` | Upstream paints a flat accent rect (`:53`); no `Gradient` exists anywhere in `bar/` except canvas wave fills. One file buys the gradient back for **every** active pill. |
| 2 | `src/quickshell/bar/modules/system/SysMonWidget.qml` | Temperature pill: `red` → accent key | Decorative use of a semantic key |
| 3 | `src/quickshell/bar/modules/MediaWidget.qml` | Hover colour: `green` → accent key | Decorative use of a semantic key |
| 4 | `src/quickshell/bar/sidemodules/SideMediaWidget.qml` | Same as 3 | Same |
| 5 | `src/quickshell/bar/modules/WorkspacesWidget.qml` **+** `src/scripts/qs_manager.sh` | Per-monitor hyprsplit ranges; lift the 10-workspace cap; fix click-to-switch dispatch | See below |

### Patch 5 in detail — the hard one

Three separate defects for a hyprsplit setup:

1. `WorkspacesWidget.qml:29` clamps `workspaceCount` to `Math.max(2, Math.min(10, …))` — a
   hard ceiling of 10. hyprsplit puts monitor 1 on 11-20, monitor 2 on 21-30
   (`workspaces.sh:52-54`: `ws_start = mon_id * WS_PER_MON + 1`).
2. Zero hyprsplit awareness — the widget builds a flat `0..count-1` model with no
   per-monitor offset.
3. `qs_manager.sh:104-109` dispatches `hyprctl dispatch 'hl.dsp.focus({ workspace = "N" })'` —
   Hyprland's **Lua** syntax. Our config is classic `hyprland.conf` style, so click-to-switch
   would fail even with the display fixed.

**Fallback if this proves messy:** omit `workspaces` from `bar.modules` and rely on hyprspace's
overview plus existing keybinds. Do not silently drop hyprsplit — it is wired through
`hyprland.nix:90-93,180-184` and the `monitorOrientations` option.

### Explicitly NOT patched

Wide active workspace pill (upstream slides a highlight under fixed dots) · in-bar
update-pending pulse (only rendered in the guide panel) · click-to-stop recording (upstream's
is non-interactive with an `mm:ss` counter) · fused clock+weather capsule with hover-scale.
Each needs its own widget rewrite for a small return and is likely to break on upstream bumps.

---

## Target settings

Starting point; tune after seeing it on Nix-Tower.

```nix
programs.serpantinum.settings = {
  general = {
    language       = "en";
    avatarPath     = <lockIcon>;      # feeds SystemInfo.avatarPath → Lock.qml:358
    muteSfx        = true;
    weatherUnit    = "metric";
    weatherInterval = 15;
    quickactions   = true;
  };

  bar = {
    position = "top";
    style    = "modular";             # LOAD-BEARING — group boxes only render here
    width    = 100;
    opacity  = 75;                    # ≈ local base@0.75
    time.format = "<match current>";
    workspaceCount = <hyprsplit-dependent, see patch 5>;
    modules = {
      left   = [ "left" "workspaces" [ "media" ] ];
      center = [ [ "timedate" "weather" ] ];
      right  = [ "info" "tray" [ "kb" "wifi" "bt" "vol" "bat" "sysmon" ] ];
    };
  };

  theme = {
    fontFamily   = "JetBrainsMono Nerd Font";
    borderRadius = 20;                # = barHeight/2 → true capsules
    matugen      = false;             # true would repaint the accent from the wallpaper
    activePreset = "Mocha";           # must NOT be "Matugen"
    colors = mochaPalette // {
      mauve = accentHex; blue = accentHex; teal = accentHex;
      sapphire = accentHex; peach = accentHex;
      # red / green deliberately left at Mocha values
    };
  };

  idle.enabled  = false;
  notifications = { dnd = false; position = "top right"; sound = true; };
  display.monitors = { /* per-host scale */ };
};
```

Every new option must be mirrored into `users/hailst0rm/hosts/default.nix` with `lib.mkDefault`,
per AGENTS.md.

---

## Phases

**Phase 0 — prep.** Add the flake input and overlay. `nix build` the package alone to confirm
it compiles against nixpkgs 26.05. Wire nothing yet.
*Verify:* package builds.

**Phase 1 — module.** New `users/hailst0rm/homeManagerModules/hyprland/serpantinum.nix`:
the `serpantinum.enable` option, the settings block above, `mkOverride 900` selectors, and an
activation script that **unconditionally** installs `settings.json` (overriding upstream's
`if [ ! -e ]` guard). Import `nixosModules.default` at system level. Mirror options into
`hosts/default.nix`. Enable on **Nix-Tower only**.
*Verify:* `nixos-rebuild build` on Nix-Tower; `settings.json` contents match the Nix block.

**Phase 2 — patches.** Land patches 1-4 (cosmetic, low risk), then patch 5.
*Verify:* build succeeds; each patch applies cleanly.

**Phase 3 — reconcile Hyprland.** Add the `screenshot` selector; make `hyprland.nix:278`'s
PRINT bind conditional; repoint widget keybinds at `serpantinum msg toggle …`; drop
`wl-screenrec` on serpantinum hosts.
*Verify:* `hyprctl binds` shows exactly one PRINT binding.

**Phase 4 — acceptance on Nix-Tower.** Checklist:
- [ ] Pills render as capsules (radius 20 at bar height 40)
- [ ] System cluster sits in one translucent group box with a hairline border
- [ ] Bar is `modular` — no continuous strip
- [ ] Every accent pill is the same colour; wifi/bt/vol/battery do not diverge
- [ ] Battery still goes green charging / red ≤15%; recording dot still red
- [ ] Active pills show the gradient (patch 1)
- [ ] hyprsplit workspaces display correctly per monitor, above 10 (patch 5)
- [ ] Clicking a workspace pill switches (patch 5)
- [ ] Notifications appear (dnd off); no UI sound effects (muteSfx on)
- [ ] Nothing dims/locks/suspends on idle (`idle.enabled = false`)
- [ ] Clipboard history and blue-light filter work
- [ ] Quickactions panel present; no desktop widgets
- [ ] Weather correct with location pinned; no IP-geolocation requests
- [ ] `lxqt-policykit` still the auth agent; no duplicate prompt

**Phase 5 — roll out.** Nix-Workstation → Nix-ExtDisk → **Nix-Laptop last** (it uses `swww`,
and the laptop battery/brightness paths now route through `syspanel`).

**Phase 6 — remove v1.** Delete `quickshell.nix`, `quickshell-config/` (21,765 lines), the
`quickshell.ilyamiro` options, and the sops `services/openweather` secret plus the
`quickshell/calendar/.env` block. The Obsidian diary hook goes with it (decision 13).
**Keep** `hyprpanel.nix`, `swaync.nix`, `hyprlock.nix`, `waybar.nix` — under `mkOverride` they
are live fallbacks again.

---

## Risks

| Risk | Mitigation |
|---|---|
| Patch 5 (hyprsplit) is the only non-cosmetic patch and touches upstream logic | Fallback: omit `workspaces` from `bar.modules`, use hyprspace + keybinds |
| Upstream churn — 25 commits in 2 days since the v2.0.0 tag, several in the home-manager path | Phased rollout; `nixos-rebuild --rollback` bounds the damage |
| `.patch` files break on upstream bumps | That is the intent — loud failure beats silent staleness |
| Settings overwritten on activation surprises in-GUI edits | Deliberate (decision 12): GUI edits are scratch, Nix is authoritative |
| v2's bar is a closed set of 15 modules with hardcoded dispatch | Anything beyond those 15 needs a new widget + `TopBar.qml` wiring — treat as out of scope |
