# DFIR lab (`cyber.dfir.enable`)

Declarative-as-possible DFIR analysis environment: a NixOS host workstation
plus VirtualBox Windows VMs built and reconciled from files in this directory.
Deployed to `~/.config/dfir/` when `cyber.dfir.enable = true`.

## Architecture

```
NixOS host (trusted)          Win-DFIR (semi-permanent)     Win-Malware (disposable)
  filesystem/memory/timeline    Zimmerman, KAPE, Arsenal,     FLARE: ghidra, x64dbg,
  static PE, YARA, volatility3  EZ tools, autopsy             procmon, fakenet, capa
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
| `config/malware-config.xml`  | FLARE `-customConfig` for the malware VM (RE/detonation subset) |
| `manifests/dfir-tools.yaml`  | Desired runtime tool state, DFIR VM |
| `manifests/malware-tools.yaml`| Desired runtime tool state, malware VM |
| `windows/update-tools.ps1`   | Convergent reconcile (installs/upgrades/removes to match a manifest) |
| `variants/dfir.yaml`         | `vbox-build-flare-vm` build config, DFIR VM |
| `variants/malware.yaml`      | `vbox-build-flare-vm` build config, malware VM |
| `host/vm-network.sh`         | `dfir-vm-network` — apply the NAT/isolated-net trust model |
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

Guest user `flare` / password `password` (the credentials
`vbox-build-flare-vm.py` hardcodes), UAC off, Guest Additions installed,
Defender best-effort off. `--wait` snapshots `BUILD-READY` once the VM powers
itself off. Tamper Protection may still need one manual GUI toggle — if so,
boot the base, turn it off, shut down, and re-take the snapshot.

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
