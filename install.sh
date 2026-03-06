#!/usr/bin/env bash
# Interactive NixOS installation script
# Uses the two-step workflow (disko then nixos-install) to avoid OOM on low-RAM systems.
# Disko formats the disk and activates swap before the build, which is the primary
# cause of OOM crashes with the single-command disko-install approach.
#
# Modes:
#   install  — Full interactive installation (default)
#   manual   — Gather values and output copy-pasteable commands (no execution)
#   Both modes support creating a new host configuration interactively.

set -euo pipefail

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# Resolve the directory this script lives in (i.e. the flake root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

info()    { echo -e "${BLUE}[*]${NC} $*"; }
ok()      { echo -e "${GREEN}[+]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
err()     { echo -e "${RED}[-]${NC} $*"; }
ask()     { echo -en "${CYAN}[?]${NC} $*"; }
header()  { echo -e "\n${BOLD}--- $* ---${NC}\n"; }
cmd()     { echo -e "  ${DIM}\$${NC} ${GREEN}$*${NC}"; }

confirm() {
    ask "$1 [y/N] "
    read -r reply
    [[ "$reply" =~ ^[Yy]$ ]]
}

confirm_yes() {
    ask "$1 [Y/n] "
    read -r reply
    [[ -z "$reply" || "$reply" =~ ^[Yy]$ ]]
}

choose() {
    # Usage: choose "prompt" option1 option2 ... — returns the selected option
    local prompt="$1"; shift
    local options=("$@")
    local i=1
    for opt in "${options[@]}"; do
        echo -e "  ${CYAN}$i)${NC} $opt"
        ((i++))
    done
    echo ""
    while true; do
        ask "$prompt "
        read -r choice
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
            CHOSEN="${options[$((choice-1))]}"
            return 0
        fi
        warn "Invalid choice. Enter a number between 1 and ${#options[@]}."
    done
}

must_be_root() {
    if [[ $EUID -ne 0 ]]; then
        err "This script must be run as root (sudo)."
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------

MODE="install"
if [[ "${1:-}" == "manual" || "${1:-}" == "--manual" || "${1:-}" == "-m" ]]; then
    MODE="manual"
fi

must_be_root

echo ""
echo -e "${BOLD}========================================${NC}"
echo -e "${BOLD}  NixOS Installation Script${NC}"
echo -e "${BOLD}========================================${NC}"
echo ""

if [[ "$MODE" == "manual" ]]; then
    info "Running in ${BOLD}manual mode${NC} — will gather values and output commands only."
else
    info "Running in ${BOLD}install mode${NC} — will execute all steps interactively."
    info "Use ${BOLD}sudo ./install.sh manual${NC} for copy-pasteable commands instead."
fi
echo ""

# Check we're on a NixOS live environment
if [[ ! -f /etc/NIXOS ]]; then
    warn "This does not appear to be a NixOS system."
    confirm "Continue anyway?" || exit 1
fi

# Check nix experimental features
if ! nix --version &>/dev/null; then
    err "nix command not found."
    exit 1
fi

# ---------------------------------------------------------------------------
# Step 1: Expand tmpfs and swap (always offer)
# ---------------------------------------------------------------------------

TOTAL_RAM_GB=$(awk '/MemTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo)
info "Detected ${BOLD}${TOTAL_RAM_GB} GB${NC} RAM."
echo ""

if [[ "$MODE" == "install" ]]; then
    if confirm_yes "Expand tmpfs backing stores? (/nix/.rw-store to 10G, / to 25G)"; then
        mount -o remount,size=10G,noatime /nix/.rw-store 2>/dev/null && ok "Expanded /nix/.rw-store to 10G" || warn "Could not expand /nix/.rw-store (may not be a tmpfs)"
        mount -o remount,size=25G,noatime / 2>/dev/null && ok "Expanded / to 25G" || warn "Could not expand / (may not be a tmpfs)"
    fi

    echo ""
    info "If you have a spare partition or USB for temporary swap, enter the device path."
    ask "Temporary swap device (leave empty to skip): "
    read -r TEMP_SWAP
    if [[ -n "$TEMP_SWAP" ]]; then
        if [[ -b "$TEMP_SWAP" ]]; then
            mkswap "$TEMP_SWAP" && swapon "$TEMP_SWAP"
            ok "Activated temporary swap on $TEMP_SWAP"
        else
            err "$TEMP_SWAP is not a block device, skipping."
        fi
    fi
    echo ""
else
    info "Recommended tmpfs expansion commands (run before installing):"
    cmd "sudo mount -o remount,size=10G,noatime /nix/.rw-store"
    cmd "sudo mount -o remount,size=25G,noatime /"
    echo ""
    info "Optional: activate temporary swap on a spare partition:"
    cmd "sudo mkswap /dev/sdX && sudo swapon /dev/sdX"
    echo ""
fi

# ---------------------------------------------------------------------------
# Step 2: Show disks and select target
# ---------------------------------------------------------------------------

header "Available Disks"
lsblk -d -o NAME,SIZE,TYPE,MODEL,TRAN | grep -v "^loop"
echo ""

# Also show RAM for swap sizing reference
info "RAM: ${BOLD}${TOTAL_RAM_GB} GB${NC} (set swap to RAM size if you want hibernation)"
echo ""

# Gather available disk names for validation
AVAILABLE_DISKS=$(lsblk -d -n -o NAME,TYPE | awk '$2=="disk" {print $1}')

ask "Target disk device name (e.g. nvme0n1, sda): "
read -r DEVICE

if [[ -z "$DEVICE" ]]; then
    err "No device specified."
    exit 1
fi

if ! echo "$AVAILABLE_DISKS" | grep -qx "$DEVICE"; then
    warn "'$DEVICE' was not found in the disk list."
    confirm "Continue anyway?" || exit 1
fi

if [[ ! -b "/dev/$DEVICE" ]]; then
    err "/dev/$DEVICE does not exist."
    exit 1
fi

DISK_SIZE=$(lsblk -b -d -n -o SIZE "/dev/$DEVICE" | awk '{printf "%.0f", $1/1024/1024/1024}')
info "Selected: ${BOLD}/dev/$DEVICE${NC} (${DISK_SIZE} GB)"
echo ""

# ---------------------------------------------------------------------------
# Step 3: Select swap size
# ---------------------------------------------------------------------------

DEFAULT_SWAP="16G"
ask "Swap size [${DEFAULT_SWAP}]: "
read -r SWAP_SIZE
SWAP_SIZE="${SWAP_SIZE:-$DEFAULT_SWAP}"
info "Swap size: ${BOLD}$SWAP_SIZE${NC}"
echo ""

# ---------------------------------------------------------------------------
# Step 4: Select or create hostname
# ---------------------------------------------------------------------------

header "Host Configurations"

# List existing hosts
AVAILABLE_HOSTS=()
for dir in "$SCRIPT_DIR"/hosts/*/; do
    host=$(basename "$dir")
    [[ "$host" == "Nix-Installer" ]] && continue
    if [[ -f "$dir/configuration.nix" ]]; then
        AVAILABLE_HOSTS+=("$host")
        if grep -q "disko" "$dir/configuration.nix" 2>/dev/null; then
            echo -e "  ${GREEN}$host${NC} (disko enabled)"
        else
            echo -e "  ${YELLOW}$host${NC} (no disko)"
        fi
    fi
done
echo -e "  ${CYAN}[new]${NC} Create a new host configuration"
echo ""

ask "Hostname to install (or 'new' to create): "
read -r HOSTNAME

if [[ -z "$HOSTNAME" ]]; then
    err "No hostname specified."
    exit 1
fi

# ---------------------------------------------------------------------------
# Step 4a: Create new host if requested
# ---------------------------------------------------------------------------

CREATE_NEW_HOST=false
if [[ "$HOSTNAME" == "new" ]]; then
    CREATE_NEW_HOST=true
    echo ""
    ask "New hostname: "
    read -r HOSTNAME

    if [[ -z "$HOSTNAME" ]]; then
        err "No hostname specified."
        exit 1
    fi

    if [[ -d "$SCRIPT_DIR/hosts/$HOSTNAME" ]]; then
        warn "Host directory $HOSTNAME already exists."
        if ! confirm "Overwrite configuration.nix?"; then
            info "Using existing configuration."
            CREATE_NEW_HOST=false
        fi
    fi
fi

if [[ "$CREATE_NEW_HOST" == "true" ]]; then
    header "New Host Configuration: $HOSTNAME"
    info "Choose options for the new host. Defaults from hosts/default.nix are shown."
    echo ""

    # --- Desktop Environment ---
    info "Desktop environment:"
    choose "Select desktop" "hyprland (default)" "gnome" "xfce" "none (headless/server)"
    case "$CHOSEN" in
        "hyprland (default)") NEW_DE="hyprland" ;;
        "gnome")              NEW_DE="gnome" ;;
        "xfce")               NEW_DE="xfce" ;;
        "none (headless/server)") NEW_DE="" ;;
    esac
    echo ""

    # --- Laptop ---
    if confirm "Is this a laptop?"; then
        NEW_LAPTOP=true
    else
        NEW_LAPTOP=false
    fi
    echo ""

    # --- GPU ---
    info "GPU drivers:"
    choose "Select GPU configuration" "None" "Intel only" "NVIDIA only" "Intel + NVIDIA (PRIME)"
    case "$CHOSEN" in
        "None")                     NEW_GPU_INTEL=false; NEW_GPU_NVIDIA=false ;;
        "Intel only")               NEW_GPU_INTEL=true;  NEW_GPU_NVIDIA=false ;;
        "NVIDIA only")              NEW_GPU_INTEL=false; NEW_GPU_NVIDIA=true ;;
        "Intel + NVIDIA (PRIME)")   NEW_GPU_INTEL=true;  NEW_GPU_NVIDIA=true ;;
    esac
    echo ""

    # --- Disko config ---
    info "Disko configuration:"
    choose "Select disko layout" "default (root, home, persist, log, swap)" "new (adds separate /nix subvolume)"
    case "$CHOSEN" in
        "default"*) NEW_DISKO="default" ;;
        "new"*)     NEW_DISKO="new" ;;
    esac
    echo ""

    # --- Sops ---
    if confirm "Enable sops-nix secret management?"; then
        NEW_SOPS=true
    else
        NEW_SOPS=false
        info "Note: password will be set to 't' for initial login (change after first boot)."
    fi
    echo ""

    # --- YubiKey ---
    if confirm "Enable YubiKey support (SSH, sudo, LUKS)?"; then
        NEW_YUBIKEY=true
    else
        NEW_YUBIKEY=false
    fi
    echo ""

    # --- Red team tools ---
    if confirm "Enable red team tools?"; then
        NEW_REDTOOLS=true
    else
        NEW_REDTOOLS=false
    fi
    echo ""

    # --- OpenSSH ---
    if confirm "Enable OpenSSH server?"; then
        NEW_SSH=true
    else
        NEW_SSH=false
    fi
    echo ""

    # --- Generate the configuration.nix ---
    HOST_DIR="$SCRIPT_DIR/hosts/$HOSTNAME"
    mkdir -p "$HOST_DIR"

    # Build the overrides section (only include non-default values)
    OVERRIDES=""

    if [[ "$NEW_DE" != "hyprland" ]]; then
        if [[ -z "$NEW_DE" ]]; then
            OVERRIDES+=$'\n  desktopEnvironment.name = "";'
            OVERRIDES+=$'\n  desktopEnvironment.displayManager.enable = false;'
        else
            OVERRIDES+=$'\n  desktopEnvironment.name = "'"$NEW_DE"'";'
        fi
    fi

    if [[ "$NEW_LAPTOP" == "true" ]]; then
        OVERRIDES+=$'\n  laptop = true;'
    fi

    if [[ "$NEW_GPU_INTEL" == "true" ]]; then
        OVERRIDES+=$'\n  graphicDriver.intel.enable = true;'
    fi

    if [[ "$NEW_GPU_NVIDIA" == "true" ]]; then
        OVERRIDES+=$'\n  graphicDriver.nvidia.enable = true;'
    fi

    if [[ "$NEW_SOPS" == "false" ]]; then
        OVERRIDES+=$'\n  security.sops.enable = false;'
    fi

    if [[ "$NEW_YUBIKEY" == "false" ]]; then
        OVERRIDES+=$'\n  security.yubikey.enable = false;'
    fi

    if [[ "$NEW_REDTOOLS" == "true" ]]; then
        OVERRIDES+=$'\n  cyber.redTools.enable = true;'
    fi

    if [[ "$NEW_SSH" == "true" ]]; then
        OVERRIDES+=$'\n  services.openssh.enable = true;'
    fi

    cat > "$HOST_DIR/configuration.nix" << NIXEOF
{inputs, ...}: let
  device = "${DEVICE}"; # IMPORTANT Set disk device (e.g. "sda", or "nvme0n1") - list with \`lsblk\`
  swapSize = "${SWAP_SIZE}"; # IMPORTANT Keep at 16GB, unless hibernation - then set to RAM size (e.g. "32G", "64G") - check with \`free -g\`
  diskoConfig = "${NEW_DISKO}";
in {
  imports = [
    ./hardware-configuration.nix
    ../default.nix

    # NixOS-Hardware
    # List: https://github.com/NixOS/nixos-hardware/blob/master/flake.nix
    # inputs.nixos-hardware.nixosModules.common-cpu-intel
    # inputs.nixos-hardware.nixosModules.common-gpu-nvidia
    # inputs.nixos-hardware.nixosModules.common-gpu-intel
    # inputs.nixos-hardware.nixosModules.common-pc-laptop
    # inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd
    # inputs.nixos-hardware.nixosModules.common-pc-ssd

    # Disk partitioning
    inputs.disko.nixosModules.disko
    ../../nixosModules/system/bootloader.nix
    ../../disko/\${diskoConfig}.nix
    {
      _module.args.device = device;
      _module.args.swapSize = swapSize;
    }
  ];

  # Override only what's different from the default${OVERRIDES}
}
NIXEOF

    ok "Created $HOST_DIR/configuration.nix"
    echo ""

    # Add to flake.nix if not already present
    if ! grep -q "\"$HOSTNAME\"" "$SCRIPT_DIR/flake.nix"; then
        info "Adding $HOSTNAME to flake.nix..."

        # Find the last mkSystem line and add after it
        LAST_MKSYSTEM=$(grep -n 'mkSystem' "$SCRIPT_DIR/flake.nix" | tail -1 | cut -d: -f1)
        if [[ -n "$LAST_MKSYSTEM" ]]; then
            sed -i "${LAST_MKSYSTEM}a\\        ${HOSTNAME} = mkSystem {hostname = \"${HOSTNAME}\";};" "$SCRIPT_DIR/flake.nix"
            ok "Added $HOSTNAME to flake.nix nixosConfigurations."
        else
            warn "Could not find mkSystem in flake.nix — add manually:"
            echo -e "  ${DIM}${HOSTNAME} = mkSystem {hostname = \"${HOSTNAME}\";};${NC}"
        fi
    else
        ok "$HOSTNAME already exists in flake.nix."
    fi
    echo ""

    info "Review the generated configuration:"
    cmd "cat $HOST_DIR/configuration.nix"
    echo ""
fi

# Set HOST_DIR for the rest of the script
HOST_DIR="$SCRIPT_DIR/hosts/$HOSTNAME"

if [[ ! -d "$HOST_DIR" ]]; then
    err "Host directory $HOST_DIR does not exist."
    exit 1
fi

# ---------------------------------------------------------------------------
# Step 5: Select disko configuration (if not creating new host)
# ---------------------------------------------------------------------------

if [[ "$CREATE_NEW_HOST" != "true" ]]; then
    # Read disko config from existing host's configuration.nix
    EXISTING_DISKO=$(grep -oP 'diskoConfig\s*=\s*"\K[^"]+' "$HOST_DIR/configuration.nix" 2>/dev/null || echo "")

    header "Disko Configurations"

    for f in "$SCRIPT_DIR"/disko/*.nix; do
        name=$(basename "$f" .nix)
        case "$name" in
            default) echo -e "  ${GREEN}default${NC} — Standard install (root, home, persist, log, swap)" ;;
            new)     echo -e "  ${GREEN}new${NC}     — Fresh install (adds separate /nix subvolume)" ;;
            *)       echo -e "  ${GREEN}$name${NC}" ;;
        esac
    done
    echo ""

    if [[ -n "$EXISTING_DISKO" ]]; then
        ask "Disko config [${EXISTING_DISKO}]: "
        read -r DISKO_CONFIG
        DISKO_CONFIG="${DISKO_CONFIG:-$EXISTING_DISKO}"
    else
        ask "Disko config [default]: "
        read -r DISKO_CONFIG
        DISKO_CONFIG="${DISKO_CONFIG:-default}"
    fi

    if [[ ! -f "$SCRIPT_DIR/disko/$DISKO_CONFIG.nix" ]]; then
        err "Disko config '$DISKO_CONFIG' not found at $SCRIPT_DIR/disko/$DISKO_CONFIG.nix"
        exit 1
    fi

    info "Disko config: ${BOLD}$DISKO_CONFIG${NC}"
    echo ""
else
    DISKO_CONFIG="$NEW_DISKO"
fi

# ---------------------------------------------------------------------------
# Step 6: Hardware config check
# ---------------------------------------------------------------------------

HW_CONFIG="$HOST_DIR/hardware-configuration.nix"
GENERATE_HW=false

if [[ -f "$HW_CONFIG" ]]; then
    ok "Existing hardware-configuration.nix found."
    if confirm "Regenerate hardware config? (recommended for new hardware)"; then
        GENERATE_HW=true
    fi
else
    warn "No hardware-configuration.nix found — will generate after formatting."
    GENERATE_HW=true
fi
echo ""

# ---------------------------------------------------------------------------
# Step 7: Summary
# ---------------------------------------------------------------------------

echo -e "${BOLD}========================================${NC}"
echo -e "${BOLD}  Installation Summary${NC}"
echo -e "${BOLD}========================================${NC}"
echo ""
echo -e "  Target disk:    ${BOLD}/dev/$DEVICE${NC} (${DISK_SIZE} GB)"
echo -e "  Swap size:      ${BOLD}$SWAP_SIZE${NC}"
echo -e "  Hostname:       ${BOLD}$HOSTNAME${NC}"
echo -e "  Disko config:   ${BOLD}$DISKO_CONFIG${NC}"
echo -e "  Generate HW:    ${BOLD}$GENERATE_HW${NC}"
echo -e "  Flake path:     ${BOLD}$SCRIPT_DIR${NC}"
echo -e "  Mode:           ${BOLD}$MODE${NC}"
if [[ "$CREATE_NEW_HOST" == "true" ]]; then
    echo -e "  New host:       ${BOLD}yes (created)${NC}"
fi
echo ""

# ===========================================================================
# MANUAL MODE — output commands and exit
# ===========================================================================

if [[ "$MODE" == "manual" ]]; then
    echo -e "${BOLD}========================================${NC}"
    echo -e "${BOLD}  Copy-Paste Commands${NC}"
    echo -e "${BOLD}========================================${NC}"
    echo ""

    info "${BOLD}Step 1: Format, encrypt, and mount the disk with disko${NC}"
    echo -e "  ${RED}WARNING: This will DESTROY all data on /dev/$DEVICE${NC}"
    echo ""
    cmd "sudo nix --experimental-features 'nix-command flakes' \\"
    echo -e "    ${GREEN}run github:nix-community/disko/latest -- \\${NC}"
    echo -e "    ${GREEN}--mode destroy,format,mount \\${NC}"
    echo -e "    ${GREEN}--flake '${SCRIPT_DIR}#${HOSTNAME}'${NC}"
    echo ""

    info "${BOLD}Step 2: Verify mounts and swap${NC}"
    cmd "mount | grep /mnt"
    cmd "swapon --show"
    echo ""

    if [[ "$GENERATE_HW" == "true" ]]; then
        info "${BOLD}Step 3: Generate hardware configuration${NC}"
        cmd "sudo nixos-generate-config --no-filesystems --root /mnt --show-hardware-config > ${HW_CONFIG}"
        echo ""
    fi

    info "${BOLD}Step $([[ "$GENERATE_HW" == "true" ]] && echo "4" || echo "3"): Copy config and prepare for flake evaluation${NC}"
    cmd "sudo mkdir -p /mnt/etc/nixos"
    cmd "sudo cp -r ${SCRIPT_DIR}/. /mnt/etc/nixos/"
    cmd "cd /mnt/etc/nixos && sudo git init -q && sudo git add -A"
    echo ""

    info "${BOLD}Step $([[ "$GENERATE_HW" == "true" ]] && echo "5" || echo "4"): (Optional) Pre-build the closure to catch errors${NC}"
    if [[ $TOTAL_RAM_GB -le 8 ]]; then
        cmd "nix build '/mnt/etc/nixos#nixosConfigurations.${HOSTNAME}.config.system.build.toplevel' \\"
        echo -e "    ${GREEN}--no-link --option max-jobs 2 --option cores 2${NC}"
    else
        cmd "nix build '/mnt/etc/nixos#nixosConfigurations.${HOSTNAME}.config.system.build.toplevel' --no-link"
    fi
    echo ""

    info "${BOLD}Step $([[ "$GENERATE_HW" == "true" ]] && echo "6" || echo "5"): Install NixOS${NC}"
    if [[ $TOTAL_RAM_GB -le 8 ]]; then
        cmd "sudo nixos-install --root /mnt \\"
        echo -e "    ${GREEN}--flake '/mnt/etc/nixos#${HOSTNAME}' \\${NC}"
        echo -e "    ${GREEN}--no-channel-copy --no-root-passwd \\${NC}"
        echo -e "    ${GREEN}--option max-jobs 2 --option cores 2${NC}"
    else
        cmd "sudo nixos-install --root /mnt \\"
        echo -e "    ${GREEN}--flake '/mnt/etc/nixos#${HOSTNAME}' \\${NC}"
        echo -e "    ${GREEN}--no-channel-copy --no-root-passwd${NC}"
    fi
    echo ""

    info "${BOLD}Step $([[ "$GENERATE_HW" == "true" ]] && echo "7" || echo "6"): Reboot${NC}"
    cmd "sudo reboot"
    echo ""

    info "${BOLD}Recovery (if install fails partway — don't reformat):${NC}"
    cmd "sudo nix run github:nix-community/disko/latest -- \\"
    echo -e "    ${GREEN}--mode mount --flake '${SCRIPT_DIR}#${HOSTNAME}'${NC}"
    cmd "sudo nixos-install --root /mnt --flake '/mnt/etc/nixos#${HOSTNAME}' --no-channel-copy --no-root-passwd"
    echo ""

    info "${BOLD}After first boot:${NC}"
    cmd "git clone https://github.com/hailst0rm1/nixos ~/.nixos"
    cmd "sudo nixos-rebuild boot --flake ~/.nixos#${HOSTNAME}"
    echo ""

    ok "Done. Copy the commands above and run them in order."
    exit 0
fi

# ===========================================================================
# INSTALL MODE — execute everything
# ===========================================================================

echo -e "  ${RED}${BOLD}WARNING: This will DESTROY all data on /dev/$DEVICE${NC}"
echo ""

if ! confirm "Proceed with installation?"; then
    info "Aborted."
    exit 0
fi

echo ""

# ---------------------------------------------------------------------------
# Step 8: Run disko (format + mount)
# ---------------------------------------------------------------------------

info "Running disko: destroy, format, and mount /dev/$DEVICE..."
echo ""

nix --experimental-features "nix-command flakes" \
    run github:nix-community/disko/latest -- \
    --mode destroy,format,mount \
    --flake "$SCRIPT_DIR#$HOSTNAME"

ok "Disko completed. Disk formatted and mounted at /mnt."
echo ""

# Verify mounts
info "Verifying mounts..."
if mountpoint -q /mnt; then
    ok "/mnt is mounted."
else
    err "/mnt is not mounted. Something went wrong with disko."
    exit 1
fi

# Show swap status (disko should have activated it)
info "Swap status:"
swapon --show 2>/dev/null || warn "No swap detected."
echo ""

# ---------------------------------------------------------------------------
# Step 9: Generate hardware config (if needed)
# ---------------------------------------------------------------------------

if [[ "$GENERATE_HW" == "true" ]]; then
    info "Generating hardware configuration..."
    nixos-generate-config --no-filesystems --root /mnt --show-hardware-config > "$HW_CONFIG"
    ok "Hardware config written to $HW_CONFIG"
    echo ""
fi

# ---------------------------------------------------------------------------
# Step 10: Copy config to mounted system and prepare for flake eval
# ---------------------------------------------------------------------------

info "Copying configuration to /mnt/etc/nixos/..."
mkdir -p /mnt/etc/nixos
cp -r "$SCRIPT_DIR"/. /mnt/etc/nixos/
# Flakes only see git-tracked files — init a repo and stage everything
(cd /mnt/etc/nixos && git init -q && git add -A)
ok "Configuration copied and staged for flake evaluation."
echo ""

# ---------------------------------------------------------------------------
# Step 11: Pre-build the closure (optional, catches config errors early)
# ---------------------------------------------------------------------------

if confirm_yes "Pre-build the system closure? (catches config errors before writing to disk)"; then
    echo ""
    info "Building system closure..."

    BUILD_ARGS=()
    if [[ $TOTAL_RAM_GB -le 8 ]]; then
        warn "Low RAM: limiting build parallelism (max-jobs=2, cores=2)."
        BUILD_ARGS+=(--option max-jobs 2 --option cores 2)
    fi

    if nix build "/mnt/etc/nixos#nixosConfigurations.$HOSTNAME.config.system.build.toplevel" \
        --no-link "${BUILD_ARGS[@]}"; then
        ok "System closure built successfully."
    else
        err "Build failed. Fix the errors above before continuing."
        echo ""
        if ! confirm "Continue with nixos-install anyway?"; then
            info "Aborted. The disk is formatted and mounted at /mnt."
            info "Fix the config, then re-run:"
            cmd "sudo nixos-install --root /mnt --flake '/mnt/etc/nixos#$HOSTNAME' --no-channel-copy --no-root-passwd"
            exit 1
        fi
    fi
    echo ""
fi

# ---------------------------------------------------------------------------
# Step 12: Install NixOS
# ---------------------------------------------------------------------------

info "Installing NixOS..."
echo ""

INSTALL_ARGS=(
    --root /mnt
    --flake "/mnt/etc/nixos#$HOSTNAME"
    --no-channel-copy
    --no-root-passwd
)

if [[ $TOTAL_RAM_GB -le 8 ]]; then
    INSTALL_ARGS+=(--option max-jobs 2 --option cores 2)
fi

nixos-install "${INSTALL_ARGS[@]}"

echo ""
ok "NixOS installation completed!"
echo ""

# ---------------------------------------------------------------------------
# Step 13: Post-install info
# ---------------------------------------------------------------------------

echo -e "${BOLD}========================================${NC}"
echo -e "${BOLD}  Installation Complete${NC}"
echo -e "${BOLD}========================================${NC}"
echo ""
echo -e "  ${GREEN}Reboot into your new system:${NC} sudo reboot"
echo ""
echo -e "  After first boot, clone your config and rebuild to the final state:"
cmd "git clone https://github.com/hailst0rm1/nixos ~/.nixos"
cmd "sudo nixos-rebuild boot --flake ~/.nixos#$HOSTNAME"
echo ""
echo -e "  ${YELLOW}Recovery (if install failed partway):${NC}"
cmd "sudo nix run github:nix-community/disko/latest -- \\"
echo -e "    ${GREEN}--mode mount --flake '${SCRIPT_DIR}#${HOSTNAME}'${NC}"
cmd "sudo nixos-install --root /mnt --flake '/mnt/etc/nixos#$HOSTNAME' --no-channel-copy --no-root-passwd"
echo ""
