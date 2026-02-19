# Hailst0rm NixOS

![Desktop Preview](/assets/images/desktop.png)

A fully declarative, modular NixOS configuration managing multiple machines from a single flake. Features full-disk encryption with YubiKey FIDO2 unlock, Hyprland Wayland desktop, comprehensive red team tooling, and secret management via sops-nix.

## Features

### System
- **Declarative disk partitioning** with [disko](https://github.com/nix-community/disko) — LUKS encryption, btrfs subvolumes, zstd compression
- **FIDO2/YubiKey unlock** at boot via systemd-cryptenroll (interactive enrollment during install)
- **Secret management** with [sops-nix](https://github.com/Mic92/sops-nix) — age-encrypted secrets for passwords, SSH keys, service credentials
- **Multiple hosts** from one flake — workstation, laptop, server, external disk, minimal installer
- **Zen kernel** by default with hardware-specific tuning via [nixos-hardware](https://github.com/NixOS/nixos-hardware)
- **Automatic system cleanup** — garbage collection and old generation pruning

### Desktop
- **Hyprland** Wayland compositor (default) with master layout, plugins (hyprsplit, hyprspace), and custom keybindings
- **GNOME**, **XFCE** also supported — set `desktopEnvironment.name` per host
- **Catppuccin Mocha** theme system-wide via [Stylix](https://github.com/danth/stylix)
- **Hyprpanel** — custom panel with system monitoring, notifications, media controls, weather
- **Rofi** app launcher, **Hyprlock** screen lock, **SwwW** wallpaper daemon, **SwayNC** notification center
- **Whisper STT** — speech-to-text with CUDA acceleration on NVIDIA systems
- **Colemak-SE** keyboard layout (custom XKB)

### Applications
- **AI**: Claude Desktop, Claude Code, Companion (Claude Code Web UI)
- **Code editors**: VS Code (31+ extensions), Helix (multi-language LSP), Claude Code
- **Terminals**: Ghostty (default), Kitty
- **Security**: Bitwarden, Proton suite (Mail, VPN, Pass, Authenticator)
- **VPN**: OpenConnect, AWS CVPN, ProtonVPN, Tailscale

### Security & Red Teaming
- **YubiKey** support for SSH, sudo (PAM u2f), and LUKS
- **150+ red team tools** — toggle with `cyber.redTools.enable = true`
  - Reconnaissance: nmap, rustscan, nuclei, ffuf, gobuster, AutoRecon
  - Web: sqlmap, nikto, wpscan, Caido
  - Exploitation: Metasploit, evil-winrm, netexec, impacket
  - Credential access: hashcat, john, hydra, Responder
  - C2: Sliver framework with MinGW cross-compilation
  - Lateral movement: BloodHound + Neo4j, ligolo-ng tunneling
  - Wordlists: SecLists, cewl, crunch
- **Malware analysis** toolkit (separate toggle)
- **Firewall** enabled by default (auto-disabled when red tools active)
- **DNScrypt** for encrypted DNS (optional)

### Services (self-hosted)
- **Tailscale** — mesh VPN with auto-connect and exit node support
- **GitLab** — self-hosted Git with PostgreSQL
- **Ghost** — blogging platform
- **Homepage** — dashboard with customizable widgets
- **Cloudflare** tunnels
- **Ollama** + **Open-WebUI** — local LLM inference
- **Vaultwarden** — self-hosted Bitwarden
- **Podman** — rootless containers with NVIDIA GPU passthrough

### GPU Support
- **Intel iGPU** — compute runtime, VA-API, force probe for newer GPUs
- **NVIDIA dGPU** — open kernel modules, PRIME offload, container toolkit, power management

---

## Installation

### Prerequisites

- A NixOS minimal ISO booted (download from [nixos.org](https://nixos.org/download))
- Internet connection
- Target disk identified with `lsblk`

```
$ lsblk
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
nvme0n1     259:0    0 476.9G  0 disk  <-- target disk
```

### Prepare the installation environment

The default NixOS minimal ISO has limited tmpfs space. For large configurations, you'll need extra swap:

1. **Create a bootable USB** (64GB recommended):
   ```shell
   dd bs=4M if=nixos-minimal.iso of=/dev/sdx status=progress oflag=sync
   ```

2. **Create a swap partition** on remaining USB space (use `gnome-disks`, `fdisk`, or `parted`)

3. **Boot into the USB** and activate swap:
   ```shell
   swapon /dev/sdx2
   mount -o remount,size=35G,noatime /nix/.rw-store
   mount -o remount,size=25G,noatime /
   ```

### Configure your host

If installing on new hardware, create a host configuration:

1. Create `hosts/<HOSTNAME>/configuration.nix` (use `Nix-Laptop` as a template)
2. Set the disk device and swap size:
   ```nix
   {inputs, ...}: let
     device = "nvme0n1";  # IMPORTANT Set disk device — check with `lsblk`
     swapSize = "16G";    # IMPORTANT Set to RAM size if hibernation — check with `free -g`
     diskoConfig = "default";
   in {
     ...
   ```
3. Generate hardware config:
   ```shell
   sudo nixos-generate-config --no-filesystems --show-hardware-config > hosts/<HOSTNAME>/hardware-configuration.nix
   ```

### Method 1: Quick install (disko-install)

Formats the disk and installs in one step. Best for minimal configs or when you're confident the build will succeed.

```shell
# Format + enroll LUKS password/YubiKey
sudo nix run 'github:nix-community/disko/latest#disko-install' \
  --extra-experimental-features "flakes nix-command" -- \
  --flake github:hailst0rm1/nixos#<HOSTNAME> \
  --write-efi-boot-entries \
  --disk x2000-<device> /dev/<device> \
  --mode format

# Install (run after format if it fails during build)
sudo nix run 'github:nix-community/disko/latest#disko-install' \
  --extra-experimental-features "flakes nix-command" -- \
  --flake github:hailst0rm1/nixos#<HOSTNAME> \
  --write-efi-boot-entries \
  --disk x2000-<device> /dev/<device> \
  --mode mount
```

> **Note:** Running `--mode format` first lets you set LUKS passwords and enroll YubiKeys interactively. If the build fails afterwards, run `--mode mount` to retry the installation without reformatting.

> Omit `--write-efi-boot-entries` if the disk will be moved to a different machine.

### Method 2: Safe install (minimal first, then full config)

Installs a minimal system first (`Nix-Minimal`), then rebuilds to the full config from the installed system. Best for large configurations.

**Step 1 — Install minimal system from the live USB:**

```shell
git clone https://github.com/hailst0rm1/nixos
```

Update `nixos/hosts/Nix-Minimal/configuration.nix` — set `device` to your target disk.

Generate hardware config if needed:
```shell
sudo nixos-generate-config --no-filesystems --show-hardware-config > nixos/hosts/Nix-Minimal/hardware-configuration.nix
```

Run disko-install:
```shell
# Format disk (interactive LUKS/YubiKey enrollment)
sudo nix run 'github:nix-community/disko/latest#disko-install' \
  --extra-experimental-features "flakes nix-command" -- \
  --flake nixos#Nix-Minimal \
  --write-efi-boot-entries \
  --disk x2000-<device> /dev/<device> \
  --mode format

# Install minimal system
sudo nix run 'github:nix-community/disko/latest#disko-install' \
  --extra-experimental-features "flakes nix-command" -- \
  --flake nixos#Nix-Minimal \
  --write-efi-boot-entries \
  --disk x2000-<device> /dev/<device> \
  --mode mount
```

**Step 2 — Reboot into the minimal system and deploy full config:**

```shell
git clone https://github.com/hailst0rm1/nixos ~/.nixos
sudo nixos-rebuild boot --flake ~/.nixos#<HOSTNAME>
```

Reboot to activate the full configuration.

### Method 3: Remote install (nixos-anywhere)

For installing on remote machines via SSH (e.g. cloud VPS).

```shell
nix run github:nix-community/nixos-anywhere -- \
  --flake <path>#<HOSTNAME> \
  --target-host root@<ip-address>
```

> **Note:** This method has not been fully tested. See the [nixos-anywhere docs](https://github.com/nix-community/nixos-anywhere) for handling secrets and extra files.

---

## Post-installation

### Secrets setup (sops-nix)

Secrets are stored per-user in `secrets/<username>.yaml`, encrypted with [age](https://github.com/FiloSottile/age).

**Generate a master age key** (store this safely — it's your recovery key):
```shell
age-keygen -o ~/.config/sops/age/keys.txt
```

**Derive an age key from your SSH key** (same SSH key always produces the same age key):
```shell
nix run nixpkgs#ssh-to-age -- -private-key -i ~/.ssh/id_hailst0rm >> ~/.config/sops/age/keys.txt
```

**Get the host's age key** (for adding to `.sops.yaml`):
```shell
nix-shell -p ssh-to-age --run 'cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age'
```

**Add keys to `.sops.yaml`**, then re-encrypt:
```shell
sops updatekeys secrets/<username>.yaml
```

**Edit secrets:**
```shell
sops secrets/<username>.yaml
```

### YubiKey setup

**Set FIDO2 PIN:**
```shell
ykman fido access change-pin
```

**Generate SSH key for YubiKey:**
```shell
ssh-keygen -t ed25519-sk -N "" -C "yubikey A" -f ~/.ssh/id_yubic
```
- Add private keys to `secrets/<username>.yaml` under `keys/ssh/`
- Add public keys to `nixosModules/system/keys/`

**Register YubiKey for sudo (PAM u2f):**
```shell
# First key
pamu2fcfg -u <username> > ~/u2f_keys

# Additional keys
pamu2fcfg -n >> ~/u2f_keys
```
Add the contents to `secrets/<username>.yaml` under `keys/yubikey/<hostname>`.

---

## Usage

### Rebuilding

The configuration provides three commands (via the rebuild script):

| Command | Description |
|---------|-------------|
| `nix-switch` | Build, activate, format with alejandra, prompt to commit |
| `nix-boot` | Build for next boot (doesn't activate immediately) |
| `nix-test` | Test build without modifying the bootloader |

All commands auto-format with `alejandra`, show a git diff, and optionally commit + push.

Pass `--legacy` to use `nixos-rebuild` instead of `nh`. Pass `--nh-flags "..."` for extra nh arguments.

### Configuration

Most settings follow a defaults-with-overrides pattern:

- **System defaults** in `hosts/default.nix`
- **Per-host overrides** in `hosts/<HOSTNAME>/configuration.nix`
- **HM defaults** in `users/<username>/hosts/default.nix`
- **Per-host HM overrides** in `users/<username>/hosts/<HOSTNAME>.nix`

You only need to set options that differ from the defaults.

### Key options

**System-level** (`hosts/<HOSTNAME>/configuration.nix`):
```nix
laptop = true;                        # Laptop-specific tweaks
cyber.redTools.enable = true;         # Red team tooling
graphicDriver.nvidia.enable = true;   # NVIDIA GPU
graphicDriver.intel.enable = true;    # Intel iGPU
security.sops.enable = false;         # Disable secrets (e.g. for portable installs)
desktopEnvironment.name = "gnome";    # Switch DE (hyprland/gnome/xfce/none)
```

**Home Manager-level** (`users/<username>/hosts/<HOSTNAME>.nix`):
```nix
code.claude-code.enable = true;       # Claude Code IDE
applications.youtube-music.enable = true;
importConfig.hyprland.accentColour = "red";
importConfig.hyprland.panel = "hyprpanel";
```

---

## Disk layout (disko)

Two disko configurations are available:

| Config | File | Use for |
|--------|------|---------|
| `default` | `disko/default.nix` | Existing systems and standard installs |
| `new` | `disko/new.nix` | Fresh installs (includes separate `/nix` subvolume) |

Set `diskoConfig = "new";` in your host's `configuration.nix` when doing a fresh install.

**Btrfs subvolumes (default):**

| Subvolume | Mount | Purpose |
|-----------|-------|---------|
| `/root` | `/` | System root |
| `/home` | `/home` | User data |
| `/persist` | `/persist` | Persistent state across rebuilds |
| `/log` | `/var/log` | System logs |
| `/swap` | `/swap` | Swap file |

The `new` config adds `/nix` as a separate subvolume — useful for impermanence and cleaner snapshots.

All subvolumes use `compress=zstd` and `noatime`.

---

## Repository structure

```
.nixos/
├── assets/           # Images and media
├── disko/            # Disk partitioning configs (default.nix, new.nix)
├── hosts/            # Per-host system configurations
│   ├── default.nix   # System-wide defaults
│   ├── Nix-Laptop/
│   ├── Nix-Workstation/
│   ├── Nix-Server/
│   ├── Nix-ExtDisk/
│   ├── Nix-Minimal/
│   └── Nix-Installer/
├── lib/              # Helper functions (generators.nix)
├── nixosModules/     # System-level modules
│   ├── desktop/      # DE configs (hyprland, gnome, xfce)
│   ├── display-manager/
│   ├── graphics/     # GPU drivers (intel, nvidia)
│   ├── security/     # sops, yubikey, polkit, sudo
│   ├── services/     # tailscale, gitlab, ghost, etc.
│   ├── system/       # bootloader, fonts, networking
│   └── variables.nix # Shared config options
├── overlays/         # Package overrides (companion, hyprpanel, responder)
├── pkgs/             # Custom packages (red team tools)
├── secrets/          # Encrypted secrets (age/sops)
├── users/
│   └── hailst0rm/
│       ├── hosts/          # Per-host HM overrides
│       └── homeManagerModules/
│           ├── code/       # Editors (vscode, helix, claude-code)
│           ├── cyber/      # Red team & malware analysis tools
│           ├── hyprland/   # Desktop environment modules
│           ├── scripts/    # Rebuild, sync, display scripts
│           └── terminal/   # Shell, terminal, CLI tools
├── flake.nix
├── flake.lock
├── shell.nix         # Dev shells (mingw, python, metasploit)
└── .sops.yaml
```