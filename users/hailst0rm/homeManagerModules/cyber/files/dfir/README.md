# DFIR lab (`cyber.dfir.enable`)

Declarative-as-possible DFIR analysis environment: a NixOS host workstation
plus VirtualBox Windows VMs built and reconciled from files in this directory.
Deployed to `~/.config/dfir/` when `cyber.dfir.enable = true`.

## Architecture

```
NixOS host (trusted)          Win-DFIR (semi-permanent)     Win-Malware (disposable)
  filesystem/memory/timeline    Zimmerman, KAPE, Arsenal,     FLARE: x64dbg, IDA,
  static PE, YARA, volatility3  EZ tools, autopsy             sysinternals, fakenet
  + FLARE's Linux-native RE
        │                            │                              │
        │  NAT ─────────────────────►│                     internal net "malware-net"
        │                                                    (no host, no forwarding)
        │                                                           │
        └───────────────────────────────────────────────► REMnux (optional, same net)
```

- **Host** does everything that *parses* evidence. Never *executes* it.
- **Win-DFIR** = Windows-native forensic parsers. NAT, integrations on.
- **Win-Malware** = sacrificial detonation box. Isolated, snapshot→run→revert.

## What Nix gives you (already done)

`cyber.dfir.enable = true` installs the host toolkit, VirtualBox, the wrapped
FLARE build scripts (`vbox-build-flare-vm`, `vbox-build-remnux`,
`vbox-clean-snapshots`, `vbox-export-snapshot`), and `dfir-vm-network`.

## Files here

| Path | Purpose |
|------|---------|
| `config/dfir-config.xml`     | FLARE `-customConfig` for the DFIR VM (forensics subset) |
| `config/malware-config.xml`  | FLARE `-customConfig` for the malware VM (FLARE's recommended set minus Linux-native tools, which `dfir.nix` puts on the host) |
| `manifests/dfir-tools.yaml`  | Desired runtime tool state, DFIR VM |
| `manifests/malware-tools.yaml`| Desired runtime tool state, malware VM |
| `windows/set-colemak-se.ps1` | Installs + enables Colemak-SE on both VMs (FLARE custom-item); the MSI is fetched by `dfir.nix` and left on the Desktop as fallback |
| `windows/LayoutModification.xml` | Taskbar pins for both VMs (Explorer, Terminal, Notepad++, Firefox), passed as `install.ps1 -customLayout` |
| `windows/update-tools.ps1`   | Convergent reconcile (installs/upgrades/removes to match a manifest) |
| `variants/dfir.yaml`         | `vbox-build-flare-vm` build config, DFIR VM |
| `variants/malware.yaml`      | `vbox-build-flare-vm` build config, malware VM |
| `host/vm-network.sh`         | `dfir-vm-network` — trust model: NAT/isolated net, plus hardware spoofing for the malware VM |
| `host/create-base-vm.sh`     | `dfir-create-base` — unattended Windows install → `BUILD-READY` |
| `host/prepare-variant.sh`    | `dfir-prepare-variant` — clone base per variant + stage FLARE inputs |

Edit the copies in the **repo** (`users/hailst0rm/homeManagerModules/cyber/files/dfir/`);
the `~/.config/dfir/` entries are read-only symlinks into the Nix store.

## Build pipeline ("when possible" — needs a real host + Windows ISO)

The FLARE scripts start from a **BUILD-READY** snapshot of a clean Windows
install on the VM they are building; they do not install Windows from ISO
(Packer is deferred). Three stages:

**1. One-time base per Windows release** — unattended, from an ISO:

```sh
dfir-create-base ~/iso/Win11_Enterprise_Eval.iso DFIR-BUILD-BASE --wait
```

Guest user `jsmith` / password `password`, on a machine named `WS-FIN-0412`.
Upstream hardcodes the account as `flare`, which evasive samples check for via
`GetUserName` and `%USERPROFILE%`; `pkgs/flare-vbox/package.nix` patches
`GUEST_USERNAME` to match the account this answer file creates. **Change the
two together or the build cannot log into the guest.** UAC off, Guest
Additions installed.
`--wait` snapshots `BUILD-READY` once the VM powers itself off.

**Then one manual step, every time you build a base.** Tamper Protection has
no scriptable off switch: `WdFilter.sys` blocks registry and PowerShell edits
to Defender's keys even as SYSTEM, which is what Tamper Protection is for. So
the answer file cannot turn Defender off, and FLARE refuses to install while
it is on. Boot the base and:

1. Windows Security → Virus & threat protection → Manage settings →
   **Tamper Protection: Off**. This is the *only* GUI-only step — while it is
   on, Group Policy and PowerShell edits to Defender are silently ignored.
2. Fully disable Defender via the Group Policy key (real-time-off alone does
   **not** count — Defender re-enables it, and FLARE's installer keeps
   reporting "Windows Defender Disabled: False"). In an **admin** PowerShell:
   ```powershell
   $p = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
   New-Item "$p\Real-Time Protection" -Force | Out-Null
   Set-ItemProperty $p DisableAntiSpyware 1 -Type DWord
   Set-ItemProperty "$p\Real-Time Protection" DisableRealtimeMonitoring 1 -Type DWord
   ```
3. **Reboot** — `DisableAntiSpyware` only takes effect after a restart (this is
   the "reboot, and rerun installer" the FLARE message asks for). Confirm it
   stuck: `Get-ItemPropertyValue "$p" DisableAntiSpyware` prints `1`.
4. Shut down, then re-take the snapshot:
   ```sh
   VBoxManage snapshot DFIR-BUILD-BASE delete BUILD-READY
   VBoxManage snapshot DFIR-BUILD-BASE take BUILD-READY \
     --description "clean Windows, UAC/Defender/Tamper off, GA installed"
   ```

This is a one-time cost per Windows release: both lab VMs clone the snapshot,
so they inherit the fixed state.

**2. Per variant, once** — the base is a single VM, but each build wants its
own VM name carrying its own `BUILD-READY`, plus its config at the fixed path
`~/FLARE-VM REQUIRED FILES/config.xml`:

```sh
dfir-prepare-variant dfir      # clone -> DFIR-Windows.testing  + stage config
dfir-prepare-variant malware   # clone -> FLARE-Windows.testing + stage config
```

It also stages `update-tools.ps1` and the variant's manifest as `tools.yaml`,
so both ride along to the guest Desktop with the config.

**3. Build (repeatable):**

```sh
# DFIR VM
vbox-build-flare-vm ~/.config/dfir/variants/dfir.yaml --custom_config
dfir-vm-network dfir DFIR-Windows.testing

# Malware VM — FLARE leaves it on a host-only adapter, so isolate it
# BEFORE detonating anything
vbox-build-flare-vm ~/.config/dfir/variants/malware.yaml --custom_config
dfir-vm-network malware FLARE-Windows.testing

# REMnux on the isolated net (optional)
vbox-build-remnux ~/.config/dfir/variants/remnux.yaml   # add later

# Snapshot hygiene / export
vbox-clean-snapshots FLARE-Windows.testing
vbox-export-snapshot FLARE-Windows.testing <snapshot> "desc" ~/dfir-exports
```

Bad package IDs in `config/*.xml` do not fail the build — check
`~/FLARE-VM LOGS/flare-vm-failed_packages.txt` afterwards.

### What `dfir-vm-network malware` hardens

Beyond the network, it removes any shared folder (a live path back to the
host), disables clipboard/drag-drop/USB, and overwrites the identifiers a
sample reads to decide it is in a sandbox:

| Identifier | VirtualBox default | After |
|---|---|---|
| SMBIOS/DMI vendor, product, serials | `innotek GmbH` / `VirtualBox` | Dell OptiPlex 7090 |
| System disk model + serial | `VBOX HARDDISK` | Samsung NVMe |
| MAC OUI | `08:00:27` (Oracle) | `00:14:22` (Dell) |

Values derive from a hash of the VM name, so re-running changes nothing and
each VM keeps a stable identity of its own. The VM must be powered off.
`dfir-vm-network unspoof <vm>` reverts the overrides — try that first if a VM
stops booting after hardening.

**This covers the static checks only.** Guest Additions remain installed and
are a stronger tell than anything above: `VBoxService.exe`, `VBoxTray.exe`,
the `VBox*` drivers and their registry keys. FLARE's build *requires* them for
`guestcontrol`, so the working order is: build with Guest Additions, then
uninstall them inside the guest before taking the analysis snapshot you
detonate from.

## Keeping tools current

- **DFIR VM (reproducibility matters):** run on demand only, never on boot:
  `powershell -File "$env:USERPROFILE\Desktop\update-tools.ps1"` (add `-DryRun`
  to preview). It defaults to `tools.yaml` beside itself.
- **Malware VM (freshness matters):** in the internet-enabled maintenance
  window run the updater, take a `clean-<date>` snapshot, *then*
  `dfir-vm-network malware <vm>` and detonate.

## Deferred (design decision C, later)

- Packer-from-ISO base build (nixpkgs `packer` is unfree/BUSL).
- REMnux variant + `vbox-build-remnux` wiring.
- Generate `config.xml` from the manifest (single source of truth).
- Eric Zimmerman CLI on the host via `dotnetCorePackages.runtime_9_0`.
