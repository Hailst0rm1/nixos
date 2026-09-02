# Serpantinum v2.0 audit vs. local fork

**Date:** 2026-08-31
**Local fork:** `users/hailst0rm/homeManagerModules/hyprland/quickshell-config/` (+ `quickshell.nix`)
**Upstream:** https://github.com/ilyamiro/serpantinum @ `d8d0d81`, version `2.0.1`

## Baselines used

| Baseline | What it is | Source |
|---|---|---|
| **LOCAL** | your fork, 63 files / 21,765 code lines | this repo |
| **V1@Apr** | upstream v1 at `17fc639` (2026-04-23) — your fork point | fork mirror `vgoer/serpantinum` |
| **V1@Aug** | upstream v1 at `5d4451f` (2026-08-08) — last v1 state, 35,431 lines | same |
| **V2** | `990615f`..`d8d0d81`, 65,162 lines | upstream `master` |

Upstream force-squashed its history at `990615f v2.0.0`, so there is no upstream v1→v2 diff.
The v1 baselines above were recovered from an untouched fork mirror.

## Headline finding

v2.0 is not an update, it is a **re-founding**. v1 was a dotfiles repo you vendored and edited;
v2 is a packaged shell (`serpantinum` / `serpantinumd` binaries, flake, NixOS module, HM module,
JSON settings schema, `serpantinum msg toggle <target>` IPC). Upstream's own migration script
(`install/modules/migrate.sh`) **backs up and discards** all v1 config — there is no config
migration path, and no file in your fork has a line-level upstream successor.

Consequence: "prioritise the remote unless my local change is documented" cannot be applied
file-by-file. The only two coherent options are (a) adopt v2 wholesale as a flake input and
re-apply your deltas as v2 settings, or (b) stay on your v1 fork and cherry-pick nothing.

---

## 1. Components you use that changed upstream

Every one was rewritten. Mapping and the substantive change:

| Your component | v2 successor | What changed |
|---|---|---|
| `Main.qml` (429) | `src/quickshell/Main.qml` + `Shell.qml` + `Runner.qml` | split into shell/runner; loaded by `serpantinumd`, not a bare `quickshell -p` |
| `TopBar.qml` (1374, monolith) | `bar/Bar.qml`, `bar/TopBar.qml` + 16 modules in `bar/modules/**` | bar is now composable via `bar.modules.{left,center,right}` in settings.json; adds autohide, opacity, `fill`/`islands` styles |
| — | `bar/SideBar.qml` + 16 `sidemodules/**` | **new**: vertical bar variant (`bar.position = left/right`) |
| `Lock.qml` (1243) | `lock/Lock.qml` + `lock/VideoLock.qml` | adds video wallpaper lock |
| `ScreenshotOverlay.qml` (758) | `screenshot/ScreenshotOverlay.qml` | + `Screenshot` notification type |
| `Scaler.qml` | `singletons/Scaler.qml` | now a real singleton |
| `MatugenColors.qml` (29) | `singletons/Matugen.qml` + `singletons/ThemeBackend.qml` | replaced by a full theming engine (see §2) |
| `WindowRegistry.js` | `src/quickshell/WindowRegistry.js` | retargeted to the new component set |
| `calendar/CalendarPopup.qml` (1579) | `calendar/CalendarPopup.qml` (1014) | **smaller** — schedule + diary removed (§3); weather units now follow global setting |
| `calendar/weather.sh` | `src/scripts/weather.sh` + `singletons/Weather.qml` | **backend swapped: OpenWeather → Open-Meteo.** No API key needed |
| — | `singletons/Location.qml` + `scripts/location.sh` | **new**: IP geolocation (ipapi.co → ip-api.com → ipwho.is) with `location_manual.sh` override; replaces City ID |
| `music/MusicPopup.qml` | `media/MusicPopup.qml` + `singletons/MprisController.qml` + `popouts/SideMusicPopout.qml` | shell scripts replaced by a singleton |
| `network/NetworkPopup.qml` (2102) | `network/NetworkPopup.qml` | now uses `Quickshell.Networking`; wifi shell logic dropped |
| `notifications/NotificationPopups.qml` (279) | `notifications/` — `NotificationCenter`, `NotificationManager`, `Notification`, `types/{Default,Screenshot,Update,Weather}` | **new**: persistent notification centre, typed/rich notifications, DND, sound picker |
| `volume/VolumePopup.qml` | `volume/VolumePopup.qml` + `singletons/Audio.qml` + `scripts/volume.sh` | polling scripts replaced by Pipewire singleton |
| `guide/GuidePopup.qml` (2385) | `guide/GuidePopup.qml` (437) + 14 tab files (~8,800 lines) | now the settings surface; **the keybinds reference page is gone entirely** (v2 is a shell, keybinds are yours) |
| `focustime/*` | `guide/wellbeing/DigitalWellbeingTab.qml` + `focus_daemon.py` + `get_stats.py` + `launch_daemon.sh` | feature survives, standalone popup does not |
| `qs_manager.sh`, `lock.sh`, `screenshot.sh` (yours) | `src/scripts/{qs_manager,lock,screenshot}.sh` | upstream now ships these; driven via `serpantinum` CLI |
| `osd/OsdBar.qml` + `osd_trigger.sh` (**yours only**) | `popouts/Osd.qml` + `singletons/widgetcontrols/OsdController.qml` | upstream grew its own OSD after your fork |

### Upstream v1 fixes you never pulled (Apr → Aug 2026)

Your fork froze at 2026-04-23. Upstream v1 continued for ~4 months. Files that grew
materially after your fork point and whose fixes are folded into v2:
`NetworkPopup.qml` +264, `UpdaterPopup.qml` +258, `notifications/NotificationPopups.qml` +105,
`Main.qml` +113, `BatteryPopup.qml` +154, `weather.sh` +38, `bluetooth_panel_logic.sh` +23,
`volume/get_audio_state.py` +23, `music_info.sh` +19.
None of these are worth back-porting individually given v2 supersedes them.

---

## 2. Components you are not using (v2 additions)

### Major features absent from your fork

| Component | What it does |
|---|---|
| `launcher/Launcher.qml` (1178) + `app_rank.py` | App launcher with frecency ranking and inline math eval. You use rofi |
| `clipboard/Clipboard.qml` (1441) + `clip_fetcher.py` | Clipboard history UI backed by `cliphist` |
| `polkit/Polkit.qml` + `PolkitService.qml` | Graphical polkit authentication agent |
| `idle/Idle.qml` (407) | Idle daemon: `dim` / `dpms` / `lock` / `suspend` with per-action timeouts, idle inhibitors, MPRIS inhibit, custom commands. Configured in `guide/IdleTab.qml` |
| `quickactions/Floating.qml` (1440) + `actions/` | Floating quick-action layer: `Dock`, `DrawAction` (screen annotation, 50 KB), `SystemUsage`, `Timer` |
| `widgets/**` — `Widget`, `WidgetLoader`, `WidgetRegistry`, `WidgetRedactor` + 12 `faces/` | Desktop widget system: clock (analog/digital/minimal), image (rect/round/rounded), music (2 faces), weather (compact/full/round), placed via a drag-and-drop redactor |
| `wallpaper/WallpaperEngine.qml` + `WallpaperPicker.qml` + `scripts/wallpaper/{ddg_search.sh,get_ddg_links.py,indexer.py,matugen_reload.sh,search_control.sh}` | Wallpaper engine with DuckDuckGo image search, thumbnail indexer, video wallpaper support, matugen re-theming on change. **You deliberately dropped this at fork** in favour of mpvpaper/swww |
| `guide/theme/**` + `singletons/ThemeBackend.qml` + `src/assets/themes/` | Theming engine: **96 bundled themes** (incl. Mocha/Frappe/Macchiato/Latte, Gruvbox, Nord, Rose Pine, Tokyo, Dracula…), live `ThemeEditor`, `FontPicker`, `theme_sorter.py` (classifies presets by accent), matugen dynamic + static modes, matugen templates for kitty/cava/fastfetch. Note: `src/assets/themes/Nightfox.json` is a 0-byte stub |
| `bar/sidemodules/SideLauncher.qml` | Inline app launcher embedded in the sidebar (fuzzy search + math evaluation), separate from the full-screen `Launcher` |
| `singletons/I18n.qml` + `src/assets/languages/` | i18n across 22 string groups; **en / de / es / ru** |
| `syspanel/SystemPanel.qml` | Consolidated system panel: battery, brightness, volume, power profiles (replaces your BatteryPopup) |
| `popouts/` — `PopoutManager`, `Osd`, `SideMusicPopout`, `TrayBase` | Popout/tray-menu framework |
| `reusables/` (20 components) | UI library: `ClickButton`, `FillButton`, `IconButton`, `CanvasIconButton`, `Draggable`, `Dropdown`, `FilePicker`, `ImagePicker`, `ImageBox`, `Input`, `PasswordInput`, `NumberSelector`, `TimeSelector`, `SliderProgress`, `Switch`, `Toggle`, `FlipIcon`, `LoaderIcon`, `NotificationBox`, `Reserved` |
| `serp/Serpantinum.qml` + `serp/Start.qml` (731) | Branded boot/intro sequence with sound design |
| `src/assets/tutorial.json` + tutorial sounds | Guided first-run tutorial |
| `singletons/Sounds.qml` + `src/assets/sounds/**` (35 files) | SFX for every interaction; `general.muteSfx` to disable |
| `singletons/Cava.qml` + `bar/modules/VisWidget.qml` + `config/cava/` | Live audio visualiser bar module |
| `singletons/Updater.qml` + `scripts/updater.py` + `notifications/types/Update.qml` | Version check + update notification (git/pacman oriented) |
| `scripts/blue_light_filter.sh` | Night-light via `wl-gammarelay-rs` |
| `scripts/brightness.sh`, `scripts/caching.sh`, `scripts/i18n.sh`, `scripts/config.sh`, `scripts/first_launch.sh`, `scripts/reload.sh`, `scripts/exit.sh`, `scripts/monitors_detect.sh`, `scripts/current_focus.sh` | Support scripts behind the `serpantinum` CLI |
| `config/sddm/themes/material-you/` | Material-You SDDM login theme (credited to Darkall44/Qylock) |
| `config/fastfetch/`, `config/kitty/`, `config/cava/` | Matugen-themed configs for those tools |
| `compositors/niri/`, `compositors/sway/` | niri and sway support (you are Hyprland-only) |

### Guide tabs you would gain

`WelcomeTab` · `general/GeneralTab` (+ `LocationInfo`) · `BarTab` (1642) · `DisplayTab` (965) ·
`IdleTab` (1013) · `LauncherTab` · `notifications/NotificationsTab` (+ `SoundPicker`) ·
`theme/ThemeTab` (1409) + `ThemeEditor` + `FontPicker` · `wellbeing/DigitalWellbeingTab` (1411) · `AboutTab`

### Nix integration you would gain

- `flake.nix` → `packages.default`, `overlays.default`, `nixosModules.default`, `homeManagerModules.default`, `apps.serpantinumd`, `devShells.default`
- `nix/nixos-module.nix` — `programs.serpantinum.enable`: NetworkManager, bluetooth, power-profiles-daemon, rtkit, pipewire (alsa+pulse), `nerd-fonts.iosevka`. All `mkDefault`
- `nix/hm-module.nix` — `programs.serpantinum.{enable,package,settings,systemd.{enable,target,environment}}`; merges your `settings` over the bundled template and installs `~/.config/serpantinum/settings.json`; runs `serpantinumd start` as a user unit
- `nix/package.nix` — wraps both binaries with `QML2_IMPORT_PATH`, `QT_PLUGIN_PATH`, `SERPANTINUM_DIR`, and a 40-package `PATH`

**Settings schema.** `nix/settings-options.nix` is a superset of the shipped
`config/serpantinum/settings.json` — several options are typed in Nix but absent from the JSON
template (marked † below).

| Group | Options |
|---|---|
| `general` | `language`, `avatarPath`, `muteSfx`, `weatherInterval` (min), `weatherUnit` (metric\|imperial), †`quickactions` (bool), †`sfxVolume` (0-100) |
| `bar` | `position` (left\|right\|top\|bottom), `width`, `opacity` (0-100), `style` (**solid\|fill\|modular**), `autohide`, `autohideTimeout` (ms), `time.format`, †`workspaceCount`, †`groupColors` (attrsOf str — per-icon-group accent overrides), `modules.{left,center,right}` (list of str or nested list) |
| `theme` | `fontFamily`, `borderRadius` (px), `activePreset`, `matugen` (bool), †**`colors`** (attrsOf str — a Catppuccin-shaped hex palette) |
| `idle` | `enabled`, †`manualInhibit`, `actions.{dim,dpms,lock,suspend}.{enabled,timeout,respectInhibitors,mprisInhibit,command,resumeCommand,†warningTimeout}`, †`customActions` (freeform list) |
| `notifications` | `dnd`, `position` (4 corners), `sound`, `soundFile` |
| `display.monitors.<name>` | `enabled`, `scale`, †`auto`, †`temperature` (colour temp override) |
| top level | `wallpaperDir`; plus a freeform `syspanel.{clipExpandProgress,clipExpanded,clipState}` passthrough |

Two things to note before writing Nix:

- **`theme.colors` is the clean landing spot for your Catppuccin pin.** It takes a full
  Catppuccin-shaped hex palette declaratively, which is a better fit than
  `activePreset = "Mocha"` and directly replaces the accent half of your generated
  `SystemConfig.qml`.
- **The README's example is wrong.** It shows `bar.style = "islands"` and
  `bar.modules.center = [ "time" ]`; the typed enum is `solid|fill|modular` and the shipped
  module name is `timedate`. Trust `nix/settings-options.nix` and
  `config/serpantinum/settings.json`, not the README.

### CLI surface

`serpantinumd start` · `serpantinum msg toggle {calendar,network,volume,music,system,guide,launcher,clipboard,wallpaper}` ·
`serpantinum {lock,reload,screenshot [--edit|--full],brightness {raise,lower},volume {raise,lower,mute-toggle,mic-toggle}}` ·
`serpantinum widgetredactor`

---

## 3. Components you use that were removed

| Yours | Fate in v2 | Impact on you |
|---|---|---|
| `settings/SettingsPopup.qml` | **Removed.** Replaced by guide tabs + `settings.json` | You'd reconfigure via guide tabs / Nix `settings` |
| `battery/BatteryPopup.qml` | **Removed.** Folded into `syspanel/SystemPanel.qml` | `SUPER+SHIFT+B` → `serpantinum msg toggle system` |
| `monitors/MonitorPopup.qml` | **Removed.** Folded into `guide/DisplayTab.qml` + `display.monitors` | `SUPER+SHIFT+D` has no direct equivalent |
| `focustime/FocusTimePopup.qml` | **Removed as a popup.** Feature survives as `DigitalWellbeingTab` | `SUPER+SHIFT+T` has no direct equivalent |
| `calendar/diary_manager.sh` | **Removed, no replacement.** | **Real loss.** Opens your Obsidian vault (`~/Life/Obsidian`) from the calendar; you run `obsidian-sync.nix`, so this is live |
| `calendar/schedule/{get_schedule.py,schedule_manager.sh}` | **Removed, no replacement.** v2's calendar has no events at all | No practical loss — see §5, already broken in your fork |
| `updater/UpdaterPopup.qml` | **Removed.** Replaced by `Updater` singleton + `Update` notification (git/pacman) | No loss — see §5, broken in your fork |
| `stewart/stewart.qml` | **Removed.** Split to `ilyamiro/stewart` | No loss — your own guide marks it "currently disabled" |
| `workspaces.sh` | **Removed.** Native `Quickshell.Hyprland` workspace API | Your per-monitor workspace customisation would need redoing as v2 settings |
| `watchers/` — 8 of 10 scripts | **Removed.** Replaced by `Quickshell.Services.{UPower,Pipewire}`, `Quickshell.Bluetooth`, `Quickshell.Networking` | Only `kb_wait.sh` survives (+ new `sys_fetcher.sh`) |
| `music/music_info.sh`, `music/player_control.sh` | **Removed.** → `MprisController` singleton | none |
| `volume/get_audio_state.py`, `volume/audio_control.sh` | **Removed.** → `Audio` singleton + `scripts/volume.sh` | none |
| `network/wifi_panel_logic.sh` | **Removed.** → `Quickshell.Networking` (only `bluetooth_panel_logic.sh` remains) | none |
| `MatugenColors.qml` | **Removed.** → `Matugen` + `ThemeBackend` singletons | Your 29-line Catppuccin-pinned version maps to picking the bundled `Mocha` theme preset |
| **OpenWeather API key + City ID** | **Removed.** Weather is Open-Meteo (keyless); location is IP-geolocated | Your entire sops `services/openweather` secret + `quickshell/calendar/.env` plumbing + `openweatherCityId` option become **dead** |
| Keybinds reference page in `GuidePopup` | **Removed.** v2 is a shell, not dotfiles — keybinds are yours | Your customised keybind table has no upstream home |

---

## 4. Your local deviations, and how documented they are

You applied ~11,500 diff lines against V1@Apr. **Three carry a written rationale:**

- `TopBar.qml:78` — `// NixOS system config (accent color, laptop flag)`
- `music/MusicPopup.qml:42` — `readonly property color lavender: _theme.blue // Mapped to blue as Matugen template lacks lavender` (your `colors.json.template` has only 19 keys, so consumers alias the missing Catppuccin accents)
- `workspaces.sh:4-6` — header documenting per-monitor JSON output "for hyprsplit compatibility"

Everything else is undocumented in code; the reasons are only recoverable from commit messages
(16 commits, 2026-04-21 → 2026-05-29). Applying your stated rule literally would discard almost
all of it — which is wrong, because several deviations are load-bearing.

| Deviation | Evidence | Keep? |
|---|---|---|
| `SystemConfig.qml` generated by Nix, injecting `accent` (Catppuccin) + `isLaptop` | `quickshell.nix:47-58`; consumed at `Main.qml:17`, `TopBar.qml:79`, `battery/BatteryPopup.qml:31`, `osd/OsdBar.qml:45` | **Obsolete in v2** — `theme.colors` takes the palette declaratively, and `SystemInfo.isDesktop` / `UPower.displayDevice.isLaptopBattery` auto-detect the form factor |
| `workspaces.sh` assumes the **hyprsplit** plugin's per-monitor workspace numbering (`ws_start = mon_id * WS_PER_MON + 1`) | `workspaces.sh:4-6,52-54` | v2's `WorkspacesWidget` + `bar.workspaceCount` uses the native Quickshell Hyprland API. **Verify hyprsplit numbering still displays correctly** — this is the deviation most likely to break on migration |
| sops OpenWeather key via `quickshell/calendar/.env` | `quickshell.nix:96-101`; `calendar/weather.sh` | **Obsolete in v2** — Open-Meteo needs no key |
| `SettingsPopup.qml` cut from 3330 → 987 lines; dropped keybind editor, OpenWeather key/City ID entry, temperature units, Telegram, Save | measured | Correct call for a declarative setup; v2 makes it moot |
| `GuidePopup.qml` 2042 → 2385: replaced upstream's keybind table with **your** NixOS keybinds | measured | Genuinely yours; no v2 home |
| `wallpaper/` dropped at fork | `diff -rq` "Only in V1: wallpaper"; `quickshell.nix:75-79` documents mpvpaper/swww choice | Deliberate and documented in the Nix module |
| Local-only `osd/OsdBar.qml` + `osd_trigger.sh` (182 lines) | commit `5c6554d`, `a5d4312` | Yours; v2 has `popouts/Osd.qml` |
| Local-only `qs_manager.sh`, `lock.sh`, `screenshot.sh` | added at import | v2 ships equivalents |
| `MonitorPopup` 1469 → 1173, `ScreenshotOverlay` 996 → 758, `UpdaterPopup` 435 → 331, `network_fetch.sh` 105 → 56, `WindowRegistry.js` 79 → 68, `TopBar` 1538 → 1374 | measured | Trimming; undocumented |
| `workspaces.sh` 101 → 115 (per-monitor workspaces) | commit `9518170` | Yours |
| Laptop GPU optimisations, global widget clamping, calendar screen-clamp, battery accent | commits `5cd9906`, `ad1f2b4`, `c1fd71d` | Yours; v2 has `Scaler` + per-monitor scale settings |

---

## 5. Pre-existing defects in your fork (found during the audit)

These are independent of v2 and are worth fixing or deleting regardless.

1. **`settings/SettingsPopup.qml:260,266`** — execs `$HOME/.config/hypr/scripts/qs_manager.sh`,
   a path that does not exist in your layout (yours is `~/.config/quickshell/qs_manager.sh`).
   The settings "Apply"/close action silently does nothing.
2. **`guide/GuidePopup.qml:418-443`** — 11 keybind rows still display upstream's
   `~/.config/hypr/scripts/*.sh` commands (`rofi_show.sh`, `rofi_clipboard.sh`,
   `focus_next_monitor.sh`, `reload.sh`). Cosmetic, but wrong on your machines.
3. **`updater/UpdaterPopup.qml`** — reachable from `TopBar.qml:717`. Checks
   `~/.local/state/imperative-dots-version` against `ilyamiro/imperative-dots` on GitHub and
   execs `~/.config/hypr/scripts/qs_manager.sh`. Meaningless on NixOS; the topbar update
   indicator reports nothing real. **Delete it and the TopBar entry.**
4. **`calendar/schedule/*` is dead.** `schedule_manager.sh:20` runs
   `nix-shell "$SHELL_NIX"`, but `shell.nix` was not copied into your fork, and `selenium`
   appears nowhere in this repo. `get_schedule.py` is a Selenium scraper for ilyamiro's
   university timetable site. Wired at `CalendarPopup.qml:337,362` but cannot run.
   **Delete `calendar/schedule/` and its two call sites.**
5. **`stewart/stewart.qml` (473 lines) is dead** — your own `GuidePopup.qml:411` labels it
   "Reserved for future, currently disabled". **Delete it, its `WindowRegistry.js:33` entry,
   and `guide/previews/preview_stewart.png`.**
6. **`guide/GuidePopup.qml:1130`** — "About" links to `github.com/ilyamiro/nixos-configuration`,
   not your repo.
7. **`WindowRegistry.js:39` — dead `sidepanel` entry** pointing at `sidepanel/SidePanel.qml`.
   No such directory or file exists anywhere in the tree, and nothing ever toggles it. If it
   were ever invoked, `Main.qml`'s `widgetStack.replace(t.comp, …)` would try to load a
   nonexistent component. **Delete the line.**
8. **The "Wallpaper Picker" module is documented and keybound but cannot open.**
   `guide/GuidePopup.qml:409` advertises it with a preview image, and `:431` binds
   `SUPER+W` → `qs_manager.sh toggle wallpaper` — but `"wallpaper"` is **not a key in
   `WindowRegistry.js`**, so `getLayout()` returns null and the toggle silently no-ops.
   Correct behaviour (you moved wallpapers to mpvpaper/swww at `quickshell.nix:69-71`),
   wrong documentation. **Remove the guide entry and the keybind row.**
9. **The guide advertises features this fork does not ship.** `GuidePopup.qml:404` promises
   "Cava visualizer, and live lyrics" — no cava invocation and no lyrics code exist anywhere
   in `music/`. The Matugen-templates explainer panel at `:2123` describes a
   kitty/nvim/rofi/cava/sddm/swaync templating pipeline, but none of `rofi.rasi`,
   `sddm-colors.qml` or `swaync/osd.css` exist in this repo. Stale upstream copy.
10. **`calendar/schedule/get_schedule.py:18-19`** hardcodes
    `PROFILE_PATH = "/home/ilyamiro/.mozilla/firefox/schedule.special"` — the *upstream
    author's* home directory — and scrapes a specific Danish school timetable
    (`all.uddataplus.dk`, `RESOURCE_ID = "99217"`). It was never adapted during the port.
    Reinforces item 4.
11. **Nothing in the tree writes `~/.cache/qs_update_pending`.** `TopBar.qml:156` polls for it
    and `:717` deletes it; there is no producer. So the update button that opens the broken
    UpdaterPopup is probably never visible in the first place — which is why item 3 has gone
    unnoticed.

Items 3–5 and 7–8 remove ~1,100 lines of unreachable code plus four stale UI entries.

---

## 6. Recommendation

**Adopt v2 as a flake input; do not merge file-by-file.** A merge is not available — the
architectures share no files.

Rough shape of the migration:

1. `inputs.serpantinum.url = "github:ilyamiro/serpantinum";` and pin it.
   Prefer `overlays.default` over `packages.${system}.default` so it builds against **your**
   nixpkgs 26.05 rather than serpantinum's own pinned `nixos-unstable`.
2. `nixosModules.default` in the host config (all `mkDefault`; check it does not fight your
   existing pipewire/bluetooth/NetworkManager settings).
3. Replace `quickshell.nix` (7.4 KB of hand-rolled `xdg.configFile` + 4 systemd units) with
   `programs.serpantinum.{enable,settings,systemd}`.
4. Re-express your deltas as `settings`: `theme.colors` (your Catppuccin palette, declaratively —
   this replaces the accent half of `SystemConfig.qml`), `theme.fontFamily`, `bar.modules.*`,
   `bar.workspaceCount`, `display.monitors.<name>.scale`, `general.weatherUnit`.
5. Keep your Hyprland keybinds in `hyprland.nix`, retargeted to the `serpantinum msg toggle …`
   CLI. `compositors/hyprland/` is written against Hyprland's Lua config API, so it is a
   reference, not a drop-in for your `hyprland.conf`-style HM config.
6. Delete the sops `services/openweather` secret, the `quickshell/calendar/.env` block, and the
   `openweatherCityId` option — all obsolete under Open-Meteo.
7. Re-implement the Obsidian diary hook yourself (a keybind to
   `xdg-open obsidian://…`), since v2 dropped it.

### Caveats to weigh before committing

- **Declarativeness regresses.** `singletons/Config.qml:28-57` writes `settings.json` in place
  via `jq`, and the HM module only installs it `if [ ! -e ]`. So settings become mutable runtime
  state. Pointing `QS_SETTINGS` at a read-only store path would make every in-GUI toggle
  silently fail.
- **Weather/location call out to the network.** `scripts/location.sh:44,72,100` geolocate by IP
  against ipapi.co / ip-api.com / ipwho.is on refresh. Given your threat model, pin it with
  `scripts/location_manual.sh`.
- **Telemetry is installer-only.** `install/modules/telemetry.sh` posts to a Cloudflare worker,
  but `nix/package.nix` fileset is `bin src config compositors version.txt` — the installer is
  **not** in the Nix build, and `grep` finds no telemetry references in `src/` or `bin/`.
  The Nix path ships none.
- **v2.0.1 is 2 days old.** 25 commits since the v2.0.0 tag are almost entirely `fix:` — several
  in the Nix/home-manager path (`6040697` bad settings module, `8dc4a2e` settings.json rewritten
  on every reload, `9279c2c` systemd unit not starting serpantinumd). Expect more churn.
- **Upstream has no tags/releases**; per this repo's AGENTS.md rule, pin the flake input to a
  commit SHA, not `master`.
