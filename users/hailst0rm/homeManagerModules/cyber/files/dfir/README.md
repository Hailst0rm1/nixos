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

Edit the copies in the **repo** (`users/hailst0rm/homeManagerModules/cyber/files/dfir/`);
the `~/.config/dfir/` entries are read-only symlinks into the Nix store.

## Build pipeline ("when possible" — needs a real host + Windows ISO)

The FLARE scripts start from a hand-made **BUILD-READY** snapshot of a clean
Windows install; they do not install Windows from ISO (that step is Packer,
deferred). One-time base per Windows release:

1. Create a VM, install Windows (guest user `flare` / password `password`,
   the credentials `vbox-build-flare-vm.py` expects), disable UAC, install
   Guest Additions, disable Defender + Tamper Protection (FLARE needs this).
2. Power off and snapshot it named exactly **`BUILD-READY`**.

Then, per VM (repeatable):

```sh
# DFIR VM
vbox-build-flare-vm ~/.config/dfir/variants/dfir.yaml --custom_config
dfir-vm-network dfir DFIR-Windows

# Malware VM (isolate BEFORE detonating anything)
vbox-build-flare-vm ~/.config/dfir/variants/malware.yaml --custom_config
dfir-vm-network malware FLARE-Windows

# REMnux on the isolated net (optional)
vbox-build-remnux ~/.config/dfir/variants/remnux.yaml   # add later

# Snapshot hygiene / export
vbox-clean-snapshots FLARE-Windows
vbox-export-snapshot FLARE-Windows <snapshot> "desc" ~/dfir-exports
```

`--custom_config` expects `config.xml` in the build's required-files dir — copy
the relevant `config/*.xml` there as `config.xml`.

## Keeping tools current

- **DFIR VM (reproducibility matters):** run on demand only, never on boot:
  `powershell -File C:\...\update-tools.ps1` (add `-DryRun` to preview).
- **Malware VM (freshness matters):** in the internet-enabled maintenance
  window run the updater, take a `clean-<date>` snapshot, *then*
  `dfir-vm-network malware <vm>` and detonate.

## Deferred (design decision C, later)

- Packer-from-ISO base build (nixpkgs `packer` is unfree/BUSL).
- REMnux variant + `vbox-build-remnux` wiring.
- Generate `config.xml` from the manifest (single source of truth).
- Eric Zimmerman CLI on the host via `dotnetCorePackages.runtime_9_0`.
