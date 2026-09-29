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
`vbox-clean-snapshots`, `vbox-export-snapshot`), `dfir-vm-network`, and the
`dfir-lab` build wizard.

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
| `host/dfir-lab.sh`           | `dfir-lab` — interactive wizard: ISO → base `BUILD-READY` → Defender step → per-variant clone + build + network |

Edit the copies in the **repo** (`users/hailst0rm/homeManagerModules/cyber/files/dfir/`);
the `~/.config/dfir/` entries are read-only symlinks into the Nix store.

## Build pipeline ("when possible" — needs a real host + Windows ISO)

The FLARE scripts start from a **BUILD-READY** snapshot of a clean Windows
install on the VM they are building; they do not install Windows from ISO
(Packer is deferred). Run the wizard and answer its prompts:

```sh
dfir-lab
```

It walks five stages, and each one checks what already exists before doing
anything — an existing base, a half-finished install, a clone that was already
built, a VM that is still running. It never deletes a VM without a yes.

1. **Base** (once per Windows release) — asks for the ISO, creates
   `DFIR-BUILD-BASE`, installs Windows unattended and snapshots `BUILD-READY`
   when the VM powers itself off. Guest user `jsmith` / password `password`,
   on a machine named `WS-FIN-0412`. Upstream hardcodes the account as `flare`,
   which evasive samples check for via `GetUserName` and `%USERPROFILE%`;
   `pkgs/flare-vbox/package.nix` patches `GUEST_USERNAME` to match the account
   the answer file creates. **Change the two together (and `GUEST_USER` in
   `host/dfir-lab.sh`) or the build cannot log into the guest.** UAC off,
   Guest Additions installed.
2. **Defender** (once per base) — the one manual step, below. The wizard
   boots the base, prints these steps, verifies the policy from inside the
   guest, and re-takes `BUILD-READY` with the description
   `clean Windows, UAC/Defender/Tamper off, GA installed`. That description is
   how later runs know this step is done.
3. **Variant** — clones the base into the variant's `VM_NAME` with its own
   `BUILD-READY`, and stages its `config.xml`, taskbar layout,
   `update-tools.ps1` and manifest (as `tools.yaml`) into
   `~/.local/share/dfir/flare-vm-required-files/`, which the build copies to
   the guest Desktop. Both variants share that directory, so the wizard stages
   each one right before its build.
4. **Build** — `vbox-build-flare-vm variants/<variant>.yaml --custom_config`.
5. **Network** — `dfir-vm-network <variant> <vm>`. FLARE leaves the malware VM
   on a host-only adapter; this isolates it before anything is detonated.

Bad package IDs in `config/*.xml` do not fail the build — check
`~/.local/state/dfir/flare-vm-logs/flare-vm-failed_packages.txt` afterwards.

Outside the wizard:

```sh
# REMnux on the isolated net (optional)
vbox-build-remnux ~/.config/dfir/variants/remnux.yaml   # add later

# Snapshot hygiene / export
vbox-clean-snapshots FLARE-Windows.testing
vbox-export-snapshot FLARE-Windows.testing <snapshot> "desc" ~/dfir-exports
```

### Disabling Defender by hand (Group Policy)

The scripts cannot do this. Tamper Protection is kernel-enforced:
`WdFilter.sys` blocks registry and PowerShell edits to Defender's keys even as
SYSTEM, so the answer file cannot turn Defender off, and FLARE refuses to
install while it is on. In the base VM's guest:

1. Windows Security → Virus & threat protection → Manage settings →
   **Tamper Protection: Off**. This is the *only* GUI-only step — while it is
   on, the policies below are silently ignored.
2. `Win+R` → `gpedit.msc` → Computer Configuration → Administrative Templates →
   Windows Components → Microsoft Defender Antivirus:
   - **Turn off Microsoft Defender Antivirus** → Enabled
   - Real-time Protection → **Turn off real-time protection** → Enabled

   Then `gpupdate /force` in an admin prompt. Real-time-off alone does **not**
   count — Defender re-enables it, and FLARE's installer keeps reporting
   "Windows Defender Disabled: False".

   No `gpedit.msc` (Home edition)? Write the same policy values from an
   **admin** PowerShell:
   ```powershell
   $p = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
   New-Item "$p\Real-Time Protection" -Force | Out-Null
   Set-ItemProperty $p DisableAntiSpyware 1 -Type DWord
   Set-ItemProperty "$p\Real-Time Protection" DisableRealtimeMonitoring 1 -Type DWord
   ```
3. **Reboot** — the policy only takes effect after a restart (this is the
   "reboot, and rerun installer" the FLARE message asks for). Confirm it stuck:
   `Get-ItemPropertyValue "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" DisableAntiSpyware`
   prints `1`.
4. Leave the guest running and let `dfir-lab` verify and re-snapshot. Without
   the wizard, shut down and:
   ```sh
   VBoxManage snapshot DFIR-BUILD-BASE delete BUILD-READY
   VBoxManage snapshot DFIR-BUILD-BASE take BUILD-READY \
     --description "clean Windows, UAC/Defender/Tamper off, GA installed"
   ```

### Non-interactive (agents, scripts)

Any flag skips the wizard and runs only the named stages, in pipeline order,
without prompts. `--rebuild` / `--reclone` are the consent to delete a VM;
without them existing VMs are kept.

```sh
dfir-lab --status                          # key=value state of base + variants
dfir-lab --iso ~/iso/Win11.iso             # create the base (no-op if it exists)
dfir-lab --defender                        # exits 3 until a human did the steps above
dfir-lab --variant both                    # clone + stage + build + network
dfir-lab --variant malware --reclone --no-build
dfir-lab --variant dfir --resume              # finish a build that died after the FLARE install
```

Exit codes: `0` ok, `1` error, `3` waiting on the manual Defender step
(re-run `dfir-lab --defender` once the guest is back up after its reboot).

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
