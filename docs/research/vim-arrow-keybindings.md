# CTRL+hjkl as real arrow keys (Hyprland + quickshell layer-shell popups)

Research date: 2026-09-02. Target: Hyprland v0.55.4 on NixOS, quickshell/serpantinum
layer-shell popups that grab keyboard focus. Goal: CTRL+h/j/k/l behave exactly like
Left/Down/Up/Right — in toplevels AND layer-shell surfaces, for taps AND hold-to-repeat.

## Verdict

**Use keyd.** A kernel-level (evdev→uinput) remapper is the only candidate that hits
all four cells of the matrix with no known bugs in the path. keyd's `[control]` layer
syntax is literally documented with this exact use case (`[control] j = down`,
`[control+alt] h = left`), it emits a *real* held Left key that Hyprland and every
client treat as hardware — so layer-shell focus routing and client-side xkb repeat
both work for free. NixOS has a first-class `services.keyd` module.

Runner-up (compositor-native, zero new daemons): Hyprland v0.55.4 **does** ship a
`sendkeystate` dispatcher that — with an *empty* window argument — injects press/release
into whatever surface currently holds seat keyboard focus, *including layer-shell
popups*. It would give real client-side repeat too, but it needs a release bind
(`bindr`) to send the key-up, and `bindr` release detection is exactly what's broken
on this install (runaway-repeat risk). Documented below in case bindr ever gets fixed.

### Matrix

| Candidate | Toplevel tap | Toplevel hold | Popup tap | Popup hold | Notes |
|---|---|---|---|---|---|
| **keyd `[control]` layer** | yes | yes | yes | yes | recommended |
| xremap (`Ctrl-h: Left`) | yes | likely | yes | likely | repeat behavior not documented upstream; per-app filtering |
| kanata | yes | likely | yes | likely | same layer as keyd; heavier config |
| Hyprland `sendkeystate` bind+bindr, empty target | yes | yes (client repeat) | yes | yes | **blocked**: bindr release never fires here → stuck "held" key |
| Current: `bind` + `wtype -k` | yes | no | yes | no | edge-triggered, no repeat |
| `binde` + wtype/ydotool | yes | broken | yes | broken | synthetic input breaks held-key tracking ([#7987]) |
| `sendshortcut …, activewindow` | yes | no | no | no | refocuses to toplevel; never reaches layer-shell |
| xkb custom type (Ctrl as level selector) | fragile | fragile | fragile | fragile | consumed-modifier handling varies per toolkit; not recommended |

## Recommended: keyd

### Why it works (primary sources)

- **Modifier+key → plain key is the documented core feature.** The keyd man page
  ([docs/keyd.scdoc]) shows `[control]` / `j = down` as its introductory example and
  states: *"bindings are not affected by the modifiers of the layer in which they are
  defined"* — so `control+j` produces an **unmodified** `down`. It also shows
  `[control+alt]` / `h = left` producing `left` while *"ignoring the control and alt
  modifiers"*, and unmapped keys keep their modifiers (`control+alt+f1` passes through
  untouched; `shift+capslock+j` → `shift+down`). CTRL keeps working normally for every
  key you don't map.
- **Repeat is real.** keyd is an evdev/uinput daemon: it grabs the physical keyboard
  and exposes a virtual one ([src/vkbd/uinput.c]). A mapped plain key mirrors the
  physical key's held state, so the compositor sees a genuinely held `KEY_LEFT`;
  Wayland repeat is then done by each client from `wl_keyboard.repeat_info`, exactly
  as for hardware arrows. The man page only special-cases repeat for *macros*
  (`macro2(<timeout>, <repeat timeout>, …)` exists precisely because macros do *not*
  repeat like normal keys) — single-key mappings need nothing.
- **Layer-shell routing is a non-issue.** Hyprland receives an ordinary key from an
  ordinary (virtual) keyboard and delivers it to the true seat keyboard focus — the
  quickshell popup when it has the grab. No `sendshortcut` target selection, no
  virtual-keyboard-protocol quirks ([#7987] only concerns Hyprland's *bind* repeat
  interacting with synthetic input; keyd's output isn't driving Hyprland binds here —
  the CTRL+hjkl binds get *removed*).

### NixOS wiring (verified options: `services.keyd.*` in nixos-25.11)

```nix
# nixosModules/hardware/keyd.nix (sketch — new module, mirror enable in hosts/default.nix)
services.keyd = {
  enable = true;
  keyboards.default = {
    ids = [ "*" ];        # or restrict to the internal keyboard's id from `keyd monitor`
    settings = {
      main = { };         # required section; leave empty to pass everything through
      control = {         # written as [control] — physical CTRL held
        h = "left";
        j = "down";
        k = "up";
        l = "right";
      };
    };
  };
};
```

Module options confirmed via NixOS options search: `services.keyd.enable`,
`services.keyd.keyboards.<name>.{ids,settings,extraConfig}`
([nixos/modules/services/hardware/keyd.nix]).

Adoption checklist:

1. Remove the current `bind = CTRL, h/j/k/l, exec, wtype …` lines from
   `users/hailst0rm/homeManagerModules/hyprland/hyprland.nix` — CTRL+hjkl will no
   longer arrive at Hyprland at all (it sees Left/Down/Up/Right), so any Hyprland
   bind on CTRL+hjkl is dead config, and leaving wtype in place would double-fire.
2. Laptop caveat: libinput's **disable-while-typing** stops working because all keys
   now come from keyd's virtual device. The keyd README documents the fix — a quirks
   entry matching the virtual keyboard ([keyd README], "disable-while-typing" section).
   The NixOS module does **not** write it for you (checked module source). On NixOS:

   ```nix
   environment.etc."libinput/local-overrides.quirks".text = ''
     [Serial Keyboards]
     MatchUdevType=keyboard
     MatchName=keyd*virtual*keyboard
     AttrKeyboardIntegration=internal
   '';
   ```

### Tradeoffs (explicit)

- **You lose CTRL+H/J/K/L in every app, system-wide.** Concretely: `^H`
  (backspace-word/char in terminals), `^J` (newline), `^K` (readline kill-line),
  `^L` (clear screen; browser focus-address-bar). This is the price of "CTRL+hjkl
  *is* arrows everywhere" — it's the same tradeoff the request implies, but now it
  applies even in apps where Hyprland binds previously wouldn't (e.g. fullscreen
  games, VMs). If that bites, the escape hatch is scoping (below) or picking a
  different modifier layer in keyd config later — one-line change.
- **Per-application exclusion is not available on Hyprland out of the box.**
  `keyd-application-mapper` *"ships with support for X, sway, and gnome (wayland)"*
  ([docs/keyd.scdoc], IPC section) — no Hyprland backend. DIY is possible: keyd's
  documented `keyd bind` IPC applies/reverts bindings at runtime, so a small script
  listening on Hyprland's socket2 `activewindow` events could toggle the mappings
  per app. Don't build this speculatively; only if a specific app conflict actually
  hurts. (If per-app rules turn out to be a hard requirement, xremap is the better
  tool — see below.)
- New always-on root daemon touching input. keyd is the most widely deployed of the
  evdev remappers and the NixOS module confines it (dedicated user, capability
  bounding); still, anything with the keyd socket is input-privileged — the man page
  says so itself.

## Runner-up: Hyprland `sendkeystate` (exists in 0.55.4 — verified in tag source)

Not in the older wiki pages, but present and registered in the v0.55.4 tree:

- Legacy-config dispatcher `sendkeystate` parses `mods, key, state, window` where
  state ∈ `down|repeat|up` ([DispatcherTranslator.cpp v0.55.4] lines 587–621, registered
  at line 834; `hyprctl.usage` describes it as *"Send a key with specific state
  (down/repeat/up) to a specified window (window must keep focus for events to
  continue)"*).
- **The window argument may be empty, and that's the important case:** with an empty
  regex the code passes a null window, and `Actions::pass(mods, key, null)` then
  *skips all refocusing* and emits the key via the seat to **whatever surface
  currently holds keyboard focus** ([ConfigActions.cpp v0.55.4] `pass()` at line 1491:
  the `setKeyboardFocus(...)` block only runs `if (window)`). That is precisely the
  path that reaches a focus-grabbing layer-shell popup — unlike
  `sendshortcut …, activewindow`, which forces focus to a toplevel first.
- The new wiki documents the same thing for the Lua config:
  `send_key_state({ window?, mods, key, state })` ([wiki dispatchers.md]).

The theoretically-clean config (client does its own repeat from a genuinely "held" key):

```
bind  = CTRL, h, sendkeystate, , left, down,   # press → key-down to current focus
bindr = CTRL, h, sendkeystate, , left, up,     # release → key-up
```

**Why it's not the recommendation:** the key-up depends on `bindr` firing on release,
and that's the exact failure already reproduced on this install (release never fired
for CTRL+hjkl; the runaway-repeat "dancing cursor"). Upstream, release-tracking bugs
were closed unfixed: [#3453] (modifier press breaks bound-key release tracking,
closed not-planned) and [#8800] (bindr not executing on release, closed not-planned).
With `sendkeystate` a missed release is *worse* than with wtype: the client believes
the arrow is held and repeats forever until something else refocuses. Using
`binde … repeat` instead avoids bindr but sends two press events per repeat tick
(state `repeat` = down+down in the source) with no release — double-stepping plus a
client-side repeat timer on top. Keep this in the back pocket for when the bindr bug
is fixed; don't ship it now.

Related, for completeness: the current bind-flag list (long-form names: `release`,
`repeating`, `non_consuming`, `auto_consuming`, `transparent`, `allow_input_capture`, …)
is in [wiki flags.md]; nothing there transforms a key or fixes release detection.

## Other candidates, briefly

- **xremap** — supports `keymap: - remap: Ctrl-h: Left` and per-application `only`/`not`
  filters; Hyprland-specific window matching needs the `hypr` build feature
  (`cargo install xremap --features hypr`, [xremap README]). nixpkgs' `xremap`
  attribute is the **wlroots** build (0.15.12, "xremap-wlroots"); the Hyprland-feature
  build comes from xremap's own flake. Held-key repeat behavior is not documented
  upstream (same uinput architecture as keyd, so it *should* pass held state through,
  but unverified — keyd's docs make the stronger case). Choose xremap over keyd only
  if per-app CTRL+hjkl exclusions become a real requirement.
- **kanata** — `services.kanata` module exists in NixOS (`enable`,
  `keyboards.<name>.{config,devices,extraDefCfg,…}`). Capable of the same mapping via
  layers, but its Lisp-style config is heavier than four INI lines for this job.
- **ydotool instead of wtype** — moves injection from the Wayland virtual-keyboard
  protocol to uinput, which changes nothing about the actual blocker: a plain `bind`
  is still edge-triggered, `binde` + synthetic input still confuses held-key tracking
  ([#7987], binde+ydotool fired once, closed stale/not-planned), and `bindr` is still
  the broken piece. No help.
- **xkb custom key type** (Control as a level selector so level N of `h` is `Left`) —
  technically expressible in xkb, but whether apps then see `Left` vs `Ctrl+Left`
  depends on each toolkit's handling of *consumed modifiers*
  ([xkbcommon consumed-modifiers docs]); behavior is inconsistent across clients, and
  Hyprland's own binds still see Control down. Fragile; rejected.

## Sources

- keyd man page (layers, `[control] j = down`, `[control+alt] h = left`, modifier
  semantics, macro2 repeat, IPC/`keyd bind`, application-mapper display-server list):
  <https://github.com/rvaiya/keyd/blob/master/docs/keyd.scdoc>
- keyd README (kernel-level operation, libinput disable-while-typing quirk):
  <https://github.com/rvaiya/keyd/blob/master/README.md>
- keyd uinput virtual device: <https://github.com/rvaiya/keyd/blob/master/src/vkbd/uinput.c>
- Hyprland v0.55.4 `sendkeystate` parsing/registration:
  <https://github.com/hyprwm/Hyprland/blob/v0.55.4/src/config/legacy/DispatcherTranslator.cpp> (lines 587–621, 834)
- Hyprland v0.55.4 `pass()`/`sendKeyState()` focus behavior (empty target → current
  seat keyboard focus, no refocus):
  <https://github.com/hyprwm/Hyprland/blob/v0.55.4/src/config/shared/actions/ConfigActions.cpp> (lines 1491–1581)
- `hyprctl.usage` dispatcher description ("window must keep focus for events to continue"):
  <https://github.com/hyprwm/Hyprland/blob/main/hyprctl/hyprctl.usage>
- Hyprland wiki (new config), dispatcher + bind-flag tables:
  <https://github.com/hyprwm/hyprland-wiki/blob/main/content/configuring/core/dispatchers.md>,
  <https://github.com/hyprwm/hyprland-wiki/blob/main/content/configuring/core/binds/flags.md>
- Hyprland issues: [#3453] release-tracking regression (closed not-planned),
  [#7987] binde + ydotool repeat (closed stale), [#8800] bindr not executing on
  release (closed not-planned)
- xremap README (Ctrl-h→Left remap syntax, `application` filters, `--features hypr`,
  NixOS flake): <https://github.com/xremap/xremap/blob/master/README.md>
- NixOS module options verified via options search: `services.keyd.*`
  (<https://github.com/NixOS/nixpkgs/blob/nixos-25.11/nixos/modules/services/hardware/keyd.nix>),
  `services.kanata.*`; nixpkgs `xremap` = xremap-wlroots 0.15.12.
- xkbcommon consumed modifiers: <https://xkbcommon.org/doc/current/group__state.html>

[docs/keyd.scdoc]: https://github.com/rvaiya/keyd/blob/master/docs/keyd.scdoc
[keyd README]: https://github.com/rvaiya/keyd/blob/master/README.md
[src/vkbd/uinput.c]: https://github.com/rvaiya/keyd/blob/master/src/vkbd/uinput.c
[DispatcherTranslator.cpp v0.55.4]: https://github.com/hyprwm/Hyprland/blob/v0.55.4/src/config/legacy/DispatcherTranslator.cpp
[ConfigActions.cpp v0.55.4]: https://github.com/hyprwm/Hyprland/blob/v0.55.4/src/config/shared/actions/ConfigActions.cpp
[wiki dispatchers.md]: https://github.com/hyprwm/hyprland-wiki/blob/main/content/configuring/core/dispatchers.md
[wiki flags.md]: https://github.com/hyprwm/hyprland-wiki/blob/main/content/configuring/core/binds/flags.md
[xremap README]: https://github.com/xremap/xremap/blob/master/README.md
[nixos/modules/services/hardware/keyd.nix]: https://github.com/NixOS/nixpkgs/blob/nixos-25.11/nixos/modules/services/hardware/keyd.nix
[xkbcommon consumed-modifiers docs]: https://xkbcommon.org/doc/current/group__state.html
[#3453]: https://github.com/hyprwm/Hyprland/issues/3453
[#7987]: https://github.com/hyprwm/Hyprland/issues/7987
[#8800]: https://github.com/hyprwm/Hyprland/issues/8800
