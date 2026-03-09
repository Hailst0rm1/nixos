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
# Early setup: repo owner, install user
# ---------------------------------------------------------------------------

REPO_OWNER=$(stat -c '%U:%G' "$SCRIPT_DIR")

# Extract the default username from hosts/default.nix
INSTALL_USER=$(grep -oP 'username\s*=\s*lib\.mkDefault\s+"\K[^"]+' "$SCRIPT_DIR/hosts/default.nix" 2>/dev/null || echo "hailst0rm")

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

fix_owner() {
    chown -R "$REPO_OWNER" "$@"
}

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

choose_default() {
    # Usage: choose_default "prompt" default_index option1 option2 ...
    # default_index is 1-based. Pressing Enter selects the default.
    local prompt="$1"; shift
    local default_idx="$1"; shift
    local options=("$@")
    local i=1
    for opt in "${options[@]}"; do
        if (( i == default_idx )); then
            echo -e "  ${CYAN}$i)${NC} $opt ${DIM}(default)${NC}"
        else
            echo -e "  ${CYAN}$i)${NC} $opt"
        fi
        ((i++))
    done
    echo ""
    while true; do
        ask "$prompt [${default_idx}] "
        read -r choice
        if [[ -z "$choice" ]]; then
            CHOSEN="${options[$((default_idx-1))]}"
            return 0
        fi
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
            CHOSEN="${options[$((choice-1))]}"
            return 0
        fi
        warn "Invalid choice. Enter a number between 1 and ${#options[@]}, or press Enter for default."
    done
}

must_be_root() {
    if [[ $EUID -ne 0 ]]; then
        err "This script must be run as root (sudo)."
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Dynamic option parsing helpers
# ---------------------------------------------------------------------------

# Parse default.nix and extract option = lib.mkDefault value pairs
# Returns lines like: option.path value
parse_nix_defaults() {
    local file="$1"
    grep -E '^\s+\S.*=\s*lib\.mkDefault\s+' "$file" | \
        sed 's/^\s*//' | \
        sed 's/\s*=\s*lib\.mkDefault\s*/ /' | \
        sed 's/;\s*$//' | \
        sed 's/\s*#.*$//' | \
        grep -v '^\s*$'
}

# Get the default value for a given option path from parsed output
get_default() {
    local option="$1"
    local defaults="$2"
    echo "$defaults" | grep "^${option} " | head -1 | sed "s/^${option} //"
}

# Prompt for a boolean option.  Returns "true" or "false".
# $1 = display label, $2 = current default ("true"/"false")
prompt_bool() {
    local label="$1"
    local default_val="$2"
    if [[ "$default_val" == "true" ]]; then
        if confirm_yes "$label?"; then echo "true"; else echo "false"; fi
    else
        if confirm "$label?"; then echo "true"; else echo "false"; fi
    fi
}

# Prompt for a string option.  Returns the user's value (or default if Enter).
# $1 = display label, $2 = current default (with or without quotes)
prompt_string() {
    local label="$1"
    local default_val="$2"
    # Strip surrounding quotes
    default_val="${default_val#\"}"
    default_val="${default_val%\"}"
    ask "$label [$default_val]: "
    read -r user_val
    if [[ -z "$user_val" ]]; then
        echo "$default_val"
    else
        echo "$user_val"
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
    info "Press Enter to keep the default value."
    echo ""

    # Parse the NixOS defaults
    NIXOS_DEFAULTS=$(parse_nix_defaults "$SCRIPT_DIR/hosts/default.nix")

    # We will collect overrides as lines for the Nix file
    OVERRIDES=""

    # ===================================================================
    # General
    # ===================================================================
    header "General"

    # username
    DEF_USERNAME=$(get_default "username" "$NIXOS_DEFAULTS")
    DEF_USERNAME="${DEF_USERNAME#\"}"
    DEF_USERNAME="${DEF_USERNAME%\"}"
    NEW_USERNAME=$(prompt_string "Username" "$DEF_USERNAME")
    if [[ "$NEW_USERNAME" != "$DEF_USERNAME" ]]; then
        OVERRIDES+=$'\n  username = "'"$NEW_USERNAME"'";'
        INSTALL_USER="$NEW_USERNAME"
    fi
    echo ""

    # myLocation
    DEF_LOCATION=$(get_default "myLocation" "$NIXOS_DEFAULTS")
    DEF_LOCATION="${DEF_LOCATION#\"}"
    DEF_LOCATION="${DEF_LOCATION%\"}"
    NEW_LOCATION=$(prompt_string "Location" "$DEF_LOCATION")
    if [[ "$NEW_LOCATION" != "$DEF_LOCATION" ]]; then
        OVERRIDES+=$'\n  myLocation = "'"$NEW_LOCATION"'";'
    fi
    echo ""

    # laptop
    DEF_LAPTOP=$(get_default "laptop" "$NIXOS_DEFAULTS")
    NEW_LAPTOP=$(prompt_bool "Laptop" "$DEF_LAPTOP")
    if [[ "$NEW_LAPTOP" != "$DEF_LAPTOP" ]]; then
        OVERRIDES+=$'\n  laptop = '"$NEW_LAPTOP"';'
    fi
    echo ""

    # removableMedia
    DEF_REMOVABLE=$(get_default "removableMedia" "$NIXOS_DEFAULTS")
    NEW_REMOVABLE=$(prompt_bool "Removable media support" "$DEF_REMOVABLE")
    if [[ "$NEW_REMOVABLE" != "$DEF_REMOVABLE" ]]; then
        OVERRIDES+=$'\n  removableMedia = '"$NEW_REMOVABLE"';'
    fi
    echo ""

    # timeZone (separate string input)
    DEF_TZ="Europe/Stockholm"
    NEW_TZ=$(prompt_string "Time zone" "$DEF_TZ")
    if [[ "$NEW_TZ" != "$DEF_TZ" ]]; then
        OVERRIDES+=$'\n  time.timeZone = "'"$NEW_TZ"'";'
    fi
    echo ""

    # locale (separate string input)
    DEF_LOCALE="en_GB.UTF-8"
    NEW_LOCALE=$(prompt_string "Default locale" "$DEF_LOCALE")
    if [[ "$NEW_LOCALE" != "$DEF_LOCALE" ]]; then
        OVERRIDES+=$'\n  i18n.defaultLocale = "'"$NEW_LOCALE"'";'
    fi
    echo ""

    # ===================================================================
    # Desktop
    # ===================================================================
    header "Desktop"

    # desktopEnvironment.name (enum menu)
    info "Desktop environment:"
    choose_default "Select desktop" 1 "hyprland" "gnome" "xfce" "none (headless/server)"
    case "$CHOSEN" in
        "hyprland")               NEW_DE="hyprland" ;;
        "gnome")                  NEW_DE="gnome" ;;
        "xfce")                   NEW_DE="xfce" ;;
        "none (headless/server)") NEW_DE="" ;;
    esac
    if [[ "$NEW_DE" != "hyprland" ]]; then
        if [[ -z "$NEW_DE" ]]; then
            OVERRIDES+=$'\n  desktopEnvironment.name = "";'
        else
            OVERRIDES+=$'\n  desktopEnvironment.name = "'"$NEW_DE"'";'
        fi
    fi
    echo ""

    # desktopEnvironment.displayManager.enable
    DEF_DM_ENABLE=$(get_default "enable" "$NIXOS_DEFAULTS" | head -1)
    # This is ambiguous — parse specifically from context. Default is true.
    DEF_DM_ENABLE="true"
    if [[ -z "$NEW_DE" ]]; then
        # Headless: disable display manager by default
        NEW_DM_ENABLE="false"
        OVERRIDES+=$'\n  desktopEnvironment.displayManager.enable = false;'
    else
        NEW_DM_ENABLE=$(prompt_bool "Display manager enabled" "$DEF_DM_ENABLE")
        if [[ "$NEW_DM_ENABLE" != "$DEF_DM_ENABLE" ]]; then
            OVERRIDES+=$'\n  desktopEnvironment.displayManager.enable = '"$NEW_DM_ENABLE"';'
        fi
    fi
    echo ""

    # desktopEnvironment.displayManager.name
    if [[ "$NEW_DM_ENABLE" == "true" ]]; then
        DEF_DM_NAME="sddm"
        NEW_DM_NAME=$(prompt_string "Display manager name" "$DEF_DM_NAME")
        if [[ "$NEW_DM_NAME" != "$DEF_DM_NAME" ]]; then
            OVERRIDES+=$'\n  desktopEnvironment.displayManager.name = "'"$NEW_DM_NAME"'";'
        fi
        echo ""
    fi

    # ===================================================================
    # Graphics
    # ===================================================================
    header "Graphics"

    DEF_GPU_INTEL=$(get_default "graphicDriver.intel.enable" "$NIXOS_DEFAULTS")
    NEW_GPU_INTEL=$(prompt_bool "Intel GPU driver" "$DEF_GPU_INTEL")
    if [[ "$NEW_GPU_INTEL" != "$DEF_GPU_INTEL" ]]; then
        OVERRIDES+=$'\n  graphicDriver.intel.enable = '"$NEW_GPU_INTEL"';'
    fi
    echo ""

    DEF_GPU_NVIDIA=$(get_default "graphicDriver.nvidia" "$NIXOS_DEFAULTS")
    # The nested block has enable inside; parse it properly
    DEF_GPU_NVIDIA_ENABLE="false"
    NEW_GPU_NVIDIA=$(prompt_bool "NVIDIA GPU driver" "$DEF_GPU_NVIDIA_ENABLE")
    if [[ "$NEW_GPU_NVIDIA" != "$DEF_GPU_NVIDIA_ENABLE" ]]; then
        OVERRIDES+=$'\n  graphicDriver.nvidia.enable = '"$NEW_GPU_NVIDIA"';'
    fi
    echo ""

    # ===================================================================
    # Security
    # ===================================================================
    header "Security"

    DEF_SOPS=$(get_default "sops.enable" "$NIXOS_DEFAULTS")
    # Multiple matches possible; we want the security.sops one
    DEF_SOPS="true"
    NEW_SOPS=$(prompt_bool "sops-nix secret management" "$DEF_SOPS")
    if [[ "$NEW_SOPS" != "$DEF_SOPS" ]]; then
        OVERRIDES+=$'\n  security.sops.enable = '"$NEW_SOPS"';'
        if [[ "$NEW_SOPS" == "false" ]]; then
            info "Note: password will be set to 't' for initial login (change after first boot)."
        fi
    fi
    echo ""

    DEF_FIREWALL="true"
    NEW_FIREWALL=$(prompt_bool "Firewall" "$DEF_FIREWALL")
    if [[ "$NEW_FIREWALL" != "$DEF_FIREWALL" ]]; then
        OVERRIDES+=$'\n  security.firewall.enable = '"$NEW_FIREWALL"';'
    fi
    echo ""

    DEF_DNSCRYPT="false"
    NEW_DNSCRYPT=$(prompt_bool "DNSCrypt" "$DEF_DNSCRYPT")
    if [[ "$NEW_DNSCRYPT" != "$DEF_DNSCRYPT" ]]; then
        OVERRIDES+=$'\n  security.dnscrypt.enable = '"$NEW_DNSCRYPT"';'
    fi
    echo ""

    DEF_POLKIT="false"
    NEW_POLKIT=$(prompt_bool "Complete Polkit rules" "$DEF_POLKIT")
    if [[ "$NEW_POLKIT" != "$DEF_POLKIT" ]]; then
        OVERRIDES+=$'\n  security.completePolkit.enable = '"$NEW_POLKIT"';'
    fi
    echo ""

    DEF_YUBIKEY="true"
    NEW_YUBIKEY=$(prompt_bool "YubiKey support (SSH, sudo, LUKS)" "$DEF_YUBIKEY")
    if [[ "$NEW_YUBIKEY" != "$DEF_YUBIKEY" ]]; then
        OVERRIDES+=$'\n  security.yubikey.enable = '"$NEW_YUBIKEY"';'
    fi
    echo ""

    # ===================================================================
    # System
    # ===================================================================
    header "System"

    # system.kernel (enum menu)
    info "Kernel:"
    choose_default "Select kernel" 1 "zen" "latest" "default"
    NEW_KERNEL="$CHOSEN"
    if [[ "$NEW_KERNEL" != "zen" ]]; then
        OVERRIDES+=$'\n  system.kernel = "'"$NEW_KERNEL"'";'
    fi
    echo ""

    # system.bootloader (enum menu)
    info "Bootloader:"
    choose_default "Select bootloader" 1 "grub" "systemd-boot"
    NEW_BOOTLOADER="$CHOSEN"
    if [[ "$NEW_BOOTLOADER" != "grub" ]]; then
        OVERRIDES+=$'\n  system.bootloader = "'"$NEW_BOOTLOADER"'";'
    fi
    echo ""

    # system.keyboard.colemak-se
    DEF_COLEMAK="true"
    NEW_COLEMAK=$(prompt_bool "Colemak-SE keyboard layout" "$DEF_COLEMAK")
    if [[ "$NEW_COLEMAK" != "$DEF_COLEMAK" ]]; then
        OVERRIDES+=$'\n  system.keyboard.colemak-se = '"$NEW_COLEMAK"';'
    fi
    echo ""

    # system.theme.enable
    DEF_THEME="true"
    NEW_THEME=$(prompt_bool "System theme (catppuccin)" "$DEF_THEME")
    if [[ "$NEW_THEME" != "$DEF_THEME" ]]; then
        OVERRIDES+=$'\n  system.theme.enable = '"$NEW_THEME"';'
    fi
    echo ""

    # system.theme.name
    if [[ "$NEW_THEME" == "true" ]]; then
        DEF_THEME_NAME="catppuccin-mocha"
        NEW_THEME_NAME=$(prompt_string "Theme name" "$DEF_THEME_NAME")
        if [[ "$NEW_THEME_NAME" != "$DEF_THEME_NAME" ]]; then
            OVERRIDES+=$'\n  system.theme.name = "'"$NEW_THEME_NAME"'";'
        fi
        echo ""
    fi

    # system.automatic.upgrade
    DEF_AUTOUPGRADE="false"
    NEW_AUTOUPGRADE=$(prompt_bool "Automatic upgrades" "$DEF_AUTOUPGRADE")
    if [[ "$NEW_AUTOUPGRADE" != "$DEF_AUTOUPGRADE" ]]; then
        OVERRIDES+=$'\n  system.automatic.upgrade = '"$NEW_AUTOUPGRADE"';'
    fi
    echo ""

    # system.automatic.cleanup
    DEF_AUTOCLEANUP="true"
    NEW_AUTOCLEANUP=$(prompt_bool "Automatic garbage collection" "$DEF_AUTOCLEANUP")
    if [[ "$NEW_AUTOCLEANUP" != "$DEF_AUTOCLEANUP" ]]; then
        OVERRIDES+=$'\n  system.automatic.cleanup = '"$NEW_AUTOCLEANUP"';'
    fi
    echo ""

    # ===================================================================
    # Hardware
    # ===================================================================
    header "Hardware"

    DEF_BT_ENABLE="true"
    NEW_BT_ENABLE=$(prompt_bool "Bluetooth" "$DEF_BT_ENABLE")
    if [[ "$NEW_BT_ENABLE" != "$DEF_BT_ENABLE" ]]; then
        OVERRIDES+=$'\n  hardware.bluetooth.enable = '"$NEW_BT_ENABLE"';'
    fi
    echo ""

    DEF_BT_POWER="false"
    NEW_BT_POWER=$(prompt_bool "Bluetooth power on boot" "$DEF_BT_POWER")
    if [[ "$NEW_BT_POWER" != "$DEF_BT_POWER" ]]; then
        OVERRIDES+=$'\n  hardware.bluetooth.powerOnBoot = '"$NEW_BT_POWER"';'
    fi
    echo ""

    # ===================================================================
    # Virtualisation
    # ===================================================================
    header "Virtualisation"

    info "${BOLD}Host virtualisation:${NC}"

    DEF_VIRT_VMWARE="false"
    NEW_VIRT_VMWARE=$(prompt_bool "VMware (host)" "$DEF_VIRT_VMWARE")
    if [[ "$NEW_VIRT_VMWARE" != "$DEF_VIRT_VMWARE" ]]; then
        OVERRIDES+=$'\n  virtualisation.host.vmware = '"$NEW_VIRT_VMWARE"';'
    fi
    echo ""

    DEF_VIRT_VBOX="true"
    NEW_VIRT_VBOX=$(prompt_bool "VirtualBox (host)" "$DEF_VIRT_VBOX")
    if [[ "$NEW_VIRT_VBOX" != "$DEF_VIRT_VBOX" ]]; then
        OVERRIDES+=$'\n  virtualisation.host.virtualbox = '"$NEW_VIRT_VBOX"';'
    fi
    echo ""

    DEF_VIRT_QEMU="false"
    NEW_VIRT_QEMU=$(prompt_bool "QEMU/KVM (host)" "$DEF_VIRT_QEMU")
    if [[ "$NEW_VIRT_QEMU" != "$DEF_VIRT_QEMU" ]]; then
        OVERRIDES+=$'\n  virtualisation.host.qemu = '"$NEW_VIRT_QEMU"';'
    fi
    echo ""

    info "${BOLD}Guest virtualisation:${NC}"

    DEF_GUEST_VMWARE="false"
    NEW_GUEST_VMWARE=$(prompt_bool "VMware (guest)" "$DEF_GUEST_VMWARE")
    if [[ "$NEW_GUEST_VMWARE" != "$DEF_GUEST_VMWARE" ]]; then
        OVERRIDES+=$'\n  virtualisation.guest.vmware = '"$NEW_GUEST_VMWARE"';'
    fi
    echo ""

    DEF_GUEST_QEMU="false"
    NEW_GUEST_QEMU=$(prompt_bool "QEMU (guest)" "$DEF_GUEST_QEMU")
    if [[ "$NEW_GUEST_QEMU" != "$DEF_GUEST_QEMU" ]]; then
        OVERRIDES+=$'\n  virtualisation.guest.qemu = '"$NEW_GUEST_QEMU"';'
    fi
    echo ""

    # ===================================================================
    # Services
    # ===================================================================
    header "Services"

    DEF_DOMAIN="pontonsecurity.com"
    NEW_DOMAIN=$(prompt_string "Domain" "$DEF_DOMAIN")
    if [[ "$NEW_DOMAIN" != "$DEF_DOMAIN" ]]; then
        OVERRIDES+=$'\n  services.domain = "'"$NEW_DOMAIN"'";'
    fi
    echo ""

    DEF_CF_ENABLE="false"
    NEW_CF_ENABLE=$(prompt_bool "Cloudflare tunnel" "$DEF_CF_ENABLE")
    if [[ "$NEW_CF_ENABLE" != "$DEF_CF_ENABLE" ]]; then
        OVERRIDES+=$'\n  services.cloudflare.enable = '"$NEW_CF_ENABLE"';'
    fi
    echo ""

    if [[ "$NEW_CF_ENABLE" == "true" ]]; then
        info "Cloudflare device type:"
        choose_default "Select device type" 1 "client" "server"
        NEW_CF_TYPE="$CHOSEN"
        if [[ "$NEW_CF_TYPE" != "client" ]]; then
            OVERRIDES+=$'\n  services.cloudflare.deviceType = "'"$NEW_CF_TYPE"'";'
        fi
        echo ""
    fi

    DEF_GITLAB_IP="100.84.181.70"
    NEW_GITLAB_IP=$(prompt_string "GitLab server IP" "$DEF_GITLAB_IP")
    if [[ "$NEW_GITLAB_IP" != "$DEF_GITLAB_IP" ]]; then
        OVERRIDES+=$'\n  services.gitlab.serverIp = "'"$NEW_GITLAB_IP"'";'
    fi
    echo ""

    DEF_PODMAN="false"
    NEW_PODMAN=$(prompt_bool "Podman containers" "$DEF_PODMAN")
    if [[ "$NEW_PODMAN" != "$DEF_PODMAN" ]]; then
        OVERRIDES+=$'\n  services.podman.enable = '"$NEW_PODMAN"';'
    fi
    echo ""

    DEF_SSH="false"
    NEW_SSH=$(prompt_bool "OpenSSH server" "$DEF_SSH")
    if [[ "$NEW_SSH" != "$DEF_SSH" ]]; then
        OVERRIDES+=$'\n  services.openssh.enable = '"$NEW_SSH"';'
    fi
    echo ""

    DEF_MATTERMOST="false"
    NEW_MATTERMOST=$(prompt_bool "Mattermost" "$DEF_MATTERMOST")
    if [[ "$NEW_MATTERMOST" != "$DEF_MATTERMOST" ]]; then
        OVERRIDES+=$'\n  services.mattermost.enable = '"$NEW_MATTERMOST"';'
    fi
    echo ""

    DEF_OLLAMA="false"
    NEW_OLLAMA=$(prompt_bool "Ollama (local AI)" "$DEF_OLLAMA")
    if [[ "$NEW_OLLAMA" != "$DEF_OLLAMA" ]]; then
        OVERRIDES+=$'\n  services.ollama.enable = '"$NEW_OLLAMA"';'
    fi
    echo ""

    DEF_OPENWEBUI="false"
    NEW_OPENWEBUI=$(prompt_bool "Open WebUI (AI frontend)" "$DEF_OPENWEBUI")
    if [[ "$NEW_OPENWEBUI" != "$DEF_OPENWEBUI" ]]; then
        OVERRIDES+=$'\n  services.open-webui.enable = '"$NEW_OPENWEBUI"';'
    fi
    echo ""

    DEF_CODESERVER="false"
    NEW_CODESERVER=$(prompt_bool "Code Server (web VS Code)" "$DEF_CODESERVER")
    if [[ "$NEW_CODESERVER" != "$DEF_CODESERVER" ]]; then
        OVERRIDES+=$'\n  services.code-server.enable = '"$NEW_CODESERVER"';'
    fi
    echo ""

    DEF_TAILSCALE="true"
    NEW_TAILSCALE=$(prompt_bool "Tailscale auto-connect" "$DEF_TAILSCALE")
    if [[ "$NEW_TAILSCALE" != "$DEF_TAILSCALE" ]]; then
        OVERRIDES+=$'\n  services.tailscaleAutoconnect.enable = '"$NEW_TAILSCALE"';'
    fi
    echo ""

    if [[ "$NEW_TAILSCALE" == "true" ]]; then
        DEF_TS_EXIT="false"
        NEW_TS_EXIT=$(prompt_bool "Advertise as Tailscale exit node" "$DEF_TS_EXIT")
        if [[ "$NEW_TS_EXIT" != "$DEF_TS_EXIT" ]]; then
            OVERRIDES+=$'\n  services.tailscaleAutoconnect.advertiseExitNode = '"$NEW_TS_EXIT"';'
        fi
        echo ""
    fi

    DEF_NAS="false"
    NEW_NAS=$(prompt_bool "NAS mount" "$DEF_NAS")
    if [[ "$NEW_NAS" != "$DEF_NAS" ]]; then
        OVERRIDES+=$'\n  services.nas.enable = '"$NEW_NAS"';'
    fi
    echo ""

    DEF_SYNCTHING="false"
    NEW_SYNCTHING=$(prompt_bool "Syncthing sync" "$DEF_SYNCTHING")
    if [[ "$NEW_SYNCTHING" != "$DEF_SYNCTHING" ]]; then
        OVERRIDES+=$'\n  services.syncthing-sync.enable = '"$NEW_SYNCTHING"';'
    fi
    echo ""

    # ===================================================================
    # Cyber
    # ===================================================================
    header "Cyber"

    DEF_REDTOOLS="false"
    NEW_REDTOOLS=$(prompt_bool "Red team tools" "$DEF_REDTOOLS")
    if [[ "$NEW_REDTOOLS" != "$DEF_REDTOOLS" ]]; then
        OVERRIDES+=$'\n  cyber.redTools.enable = '"$NEW_REDTOOLS"';'
    fi
    echo ""

    # ===================================================================
    # Disko config
    # ===================================================================
    header "Disk Layout"

    info "Disko configuration:"
    choose_default "Select disko layout" 1 "default (root, home, persist, log, swap)" "new (adds separate /nix subvolume)"
    case "$CHOSEN" in
        "default"*) NEW_DISKO="default" ;;
        "new"*)     NEW_DISKO="new" ;;
    esac
    echo ""

    # --- Generate the NixOS configuration.nix ---
    HOST_DIR="$SCRIPT_DIR/hosts/$HOSTNAME"
    mkdir -p "$HOST_DIR"
    fix_owner "$HOST_DIR"

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

    fix_owner "$HOST_DIR/configuration.nix"
    ok "Created $HOST_DIR/configuration.nix"
    echo ""

    # ===================================================================
    # Generate Home Manager host file
    # ===================================================================

    header "Home Manager Configuration: $HOSTNAME"
    info "Choose Home Manager options. Defaults from users/$INSTALL_USER/hosts/default.nix are shown."
    info "Press Enter to keep the default value."
    echo ""

    HM_DEFAULTS_FILE="$SCRIPT_DIR/users/$INSTALL_USER/hosts/default.nix"
    HM_OVERRIDES=""

    if [[ -f "$HM_DEFAULTS_FILE" ]]; then
        HM_DEFAULTS=$(parse_nix_defaults "$HM_DEFAULTS_FILE")

        # ==============================================================
        # Terminal / Apps
        # ==============================================================
        header "Terminal / Apps"

        DEF_TERMINAL="ghostty"
        NEW_TERMINAL=$(prompt_string "Terminal emulator" "$DEF_TERMINAL")
        if [[ "$NEW_TERMINAL" != "$DEF_TERMINAL" ]]; then
            HM_OVERRIDES+=$'\n  terminal = "'"$NEW_TERMINAL"'";'
        fi
        echo ""

        DEF_SHELL="zsh"
        NEW_SHELL=$(prompt_string "Shell" "$DEF_SHELL")
        if [[ "$NEW_SHELL" != "$DEF_SHELL" ]]; then
            HM_OVERRIDES+=$'\n  shell = "'"$NEW_SHELL"'";'
        fi
        echo ""

        DEF_EDITOR="hx"
        NEW_EDITOR=$(prompt_string "Editor" "$DEF_EDITOR")
        if [[ "$NEW_EDITOR" != "$DEF_EDITOR" ]]; then
            HM_OVERRIDES+=$'\n  editor = "'"$NEW_EDITOR"'";'
        fi
        echo ""

        DEF_FM="nautilus"
        NEW_FM=$(prompt_string "File manager" "$DEF_FM")
        if [[ "$NEW_FM" != "$DEF_FM" ]]; then
            HM_OVERRIDES+=$'\n  fileManager = "'"$NEW_FM"'";'
        fi
        echo ""

        DEF_BROWSER="firefox"
        NEW_BROWSER=$(prompt_string "Browser" "$DEF_BROWSER")
        if [[ "$NEW_BROWSER" != "$DEF_BROWSER" ]]; then
            HM_OVERRIDES+=$'\n  browser = "'"$NEW_BROWSER"'";'
        fi
        echo ""

        DEF_VIDEO="totem"
        NEW_VIDEO=$(prompt_string "Video player" "$DEF_VIDEO")
        if [[ "$NEW_VIDEO" != "$DEF_VIDEO" ]]; then
            HM_OVERRIDES+=$'\n  video = "'"$NEW_VIDEO"'";'
        fi
        echo ""

        DEF_IMAGE="loupe"
        NEW_IMAGE=$(prompt_string "Image viewer" "$DEF_IMAGE")
        if [[ "$NEW_IMAGE" != "$DEF_IMAGE" ]]; then
            HM_OVERRIDES+=$'\n  image = "'"$NEW_IMAGE"'";'
        fi
        echo ""

        DEF_KB="colemak-se,se"
        NEW_KB=$(prompt_string "Keyboard layout" "$DEF_KB")
        if [[ "$NEW_KB" != "$DEF_KB" ]]; then
            HM_OVERRIDES+=$'\n  keyboard = "'"$NEW_KB"'";'
        fi
        echo ""

        # ==============================================================
        # Import Config
        # ==============================================================
        header "Import Config"

        DEF_GIT="true"
        NEW_GIT=$(prompt_bool "Git config" "$DEF_GIT")
        if [[ "$NEW_GIT" != "$DEF_GIT" ]]; then
            HM_OVERRIDES+=$'\n  importConfig.git.enable = '"$NEW_GIT"';'
        fi
        echo ""

        DEF_SSHCFG="true"
        NEW_SSHCFG=$(prompt_bool "SSH config" "$DEF_SSHCFG")
        if [[ "$NEW_SSHCFG" != "$DEF_SSHCFG" ]]; then
            HM_OVERRIDES+=$'\n  importConfig.ssh.enable = '"$NEW_SSHCFG"';'
        fi
        echo ""

        DEF_YAZI="true"
        NEW_YAZI=$(prompt_bool "Yazi file manager config" "$DEF_YAZI")
        if [[ "$NEW_YAZI" != "$DEF_YAZI" ]]; then
            HM_OVERRIDES+=$'\n  importConfig.yazi.enable = '"$NEW_YAZI"';'
        fi
        echo ""

        DEF_STYLIX="true"
        NEW_STYLIX=$(prompt_bool "Stylix theming" "$DEF_STYLIX")
        if [[ "$NEW_STYLIX" != "$DEF_STYLIX" ]]; then
            HM_OVERRIDES+=$'\n  importConfig.stylix.enable = '"$NEW_STYLIX"';'
        fi
        echo ""

        DEF_ZSH_SYNC="true"
        NEW_ZSH_SYNC=$(prompt_bool "Zsh history sync" "$DEF_ZSH_SYNC")
        if [[ "$NEW_ZSH_SYNC" != "$DEF_ZSH_SYNC" ]]; then
            HM_OVERRIDES+=$'\n  importConfig.zsh-history-sync.enable = '"$NEW_ZSH_SYNC"';'
        fi
        echo ""

        # ==============================================================
        # Hyprland
        # ==============================================================
        header "Hyprland"

        DEF_HYPR_ENABLE="true"
        NEW_HYPR_ENABLE=$(prompt_bool "Hyprland config" "$DEF_HYPR_ENABLE")
        if [[ "$NEW_HYPR_ENABLE" != "$DEF_HYPR_ENABLE" ]]; then
            HM_OVERRIDES+=$'\n  importConfig.hyprland.enable = '"$NEW_HYPR_ENABLE"';'
        fi
        echo ""

        if [[ "$NEW_HYPR_ENABLE" == "true" ]]; then
            # accentColour (enum menu)
            info "Hyprland accent colour:"
            choose_default "Select colour" 9 \
                "rosewater" "flamingo" "pink" "mauve" "red" "maroon" "peach" "yellow" \
                "green" "teal" "sky" "sapphire" "blue" "lavender"
            NEW_ACCENT="$CHOSEN"
            if [[ "$NEW_ACCENT" != "green" ]]; then
                HM_OVERRIDES+=$'\n  importConfig.hyprland.accentColour = "'"$NEW_ACCENT"'";'
            fi
            echo ""

            DEF_PANEL="hyprpanel"
            NEW_PANEL=$(prompt_string "Panel" "$DEF_PANEL")
            if [[ "$NEW_PANEL" != "$DEF_PANEL" ]]; then
                HM_OVERRIDES+=$'\n  importConfig.hyprland.panel = "'"$NEW_PANEL"'";'
            fi
            echo ""

            DEF_LOCK="hyprlock"
            NEW_LOCK=$(prompt_string "Lockscreen" "$DEF_LOCK")
            if [[ "$NEW_LOCK" != "$DEF_LOCK" ]]; then
                HM_OVERRIDES+=$'\n  importConfig.hyprland.lockscreen = "'"$NEW_LOCK"'";'
            fi
            echo ""

            DEF_LAUNCHER="rofi"
            NEW_LAUNCHER=$(prompt_string "App launcher" "$DEF_LAUNCHER")
            if [[ "$NEW_LAUNCHER" != "$DEF_LAUNCHER" ]]; then
                HM_OVERRIDES+=$'\n  importConfig.hyprland.appLauncher = "'"$NEW_LAUNCHER"'";'
            fi
            echo ""

            DEF_NOTIF="hyprpanel"
            NEW_NOTIF=$(prompt_string "Notifications" "$DEF_NOTIF")
            if [[ "$NEW_NOTIF" != "$DEF_NOTIF" ]]; then
                HM_OVERRIDES+=$'\n  importConfig.hyprland.notifications = "'"$NEW_NOTIF"'";'
            fi
            echo ""

            DEF_WALL="swww"
            NEW_WALL=$(prompt_string "Wallpaper" "$DEF_WALL")
            if [[ "$NEW_WALL" != "$DEF_WALL" ]]; then
                HM_OVERRIDES+=$'\n  importConfig.hyprland.wallpaper = "'"$NEW_WALL"'";'
            fi
            echo ""

            DEF_SCREENPICKER="true"
            NEW_SCREENPICKER=$(prompt_bool "Custom screen picker" "$DEF_SCREENPICKER")
            if [[ "$NEW_SCREENPICKER" != "$DEF_SCREENPICKER" ]]; then
                HM_OVERRIDES+=$'\n  importConfig.hyprland.customScreenPicker = '"$NEW_SCREENPICKER"';'
            fi
            echo ""
        fi

        # ==============================================================
        # IDE
        # ==============================================================
        header "IDE"

        DEF_CLAUDE_CODE="false"
        NEW_CLAUDE_CODE=$(prompt_bool "Claude Code" "$DEF_CLAUDE_CODE")
        if [[ "$NEW_CLAUDE_CODE" != "$DEF_CLAUDE_CODE" ]]; then
            HM_OVERRIDES+=$'\n  code.claude-code.enable = '"$NEW_CLAUDE_CODE"';'
        fi
        echo ""

        DEF_HELIX="true"
        NEW_HELIX=$(prompt_bool "Helix editor" "$DEF_HELIX")
        if [[ "$NEW_HELIX" != "$DEF_HELIX" ]]; then
            HM_OVERRIDES+=$'\n  code.helix.enable = '"$NEW_HELIX"';'
        fi
        echo ""

        DEF_VSCODE="true"
        NEW_VSCODE=$(prompt_bool "VS Code" "$DEF_VSCODE")
        if [[ "$NEW_VSCODE" != "$DEF_VSCODE" ]]; then
            HM_OVERRIDES+=$'\n  code.vscode.enable = '"$NEW_VSCODE"';'
        fi
        echo ""

        # ==============================================================
        # Applications
        # ==============================================================
        header "Applications"

        # Application boolean toggles
        declare -A HM_APPS=(
            ["bitwarden"]="true"
            ["brave"]="false"
            ["discord"]="true"
            ["firefox"]="true"
            ["gpt4all"]="false"
            ["libreOffice"]="true"
            ["mattermost"]="false"
            ["obsidian"]="true"
            ["remmina"]="true"
            ["spotify"]="true"
            ["youtube-music"]="false"
            ["zen-browser"]="false"
            ["claude-desktop"]="true"
            ["openconnect"]="false"
            ["espanso"]="false"
            ["aws-cvpn-wrapper"]="false"
        )
        # Preserve order with an array
        HM_APP_ORDER=(
            "bitwarden" "brave" "discord" "firefox" "gpt4all"
            "libreOffice" "mattermost" "obsidian" "remmina" "spotify"
            "youtube-music" "zen-browser" "claude-desktop" "openconnect"
            "espanso" "aws-cvpn-wrapper"
        )

        for app in "${HM_APP_ORDER[@]}"; do
            def="${HM_APPS[$app]}"
            result=$(prompt_bool "$app" "$def")
            if [[ "$result" != "$def" ]]; then
                HM_OVERRIDES+=$'\n  applications.'"$app"'.enable = '"$result"';'
            fi
            echo ""
        done

        # Proton suite
        info "${BOLD}Proton suite:${NC}"

        DEF_PROTON_ALL="true"
        NEW_PROTON_ALL=$(prompt_bool "Proton (enable all)" "$DEF_PROTON_ALL")
        if [[ "$NEW_PROTON_ALL" != "$DEF_PROTON_ALL" ]]; then
            HM_OVERRIDES+=$'\n  applications.proton.enableAll = '"$NEW_PROTON_ALL"';'
        fi
        echo ""

        # Individual proton apps (only ask if enableAll is false)
        if [[ "$NEW_PROTON_ALL" == "false" ]]; then
            for papp in mail vpn pass authenticator; do
                DEF_PAPP="false"
                NEW_PAPP=$(prompt_bool "Proton $papp" "$DEF_PAPP")
                if [[ "$NEW_PAPP" != "$DEF_PAPP" ]]; then
                    HM_OVERRIDES+=$'\n  applications.proton.'"$papp"'.enable = '"$NEW_PAPP"';'
                fi
                echo ""
            done
        fi

        # Games
        info "${BOLD}Games:${NC}"
        DEF_RYUJINX="false"
        NEW_RYUJINX=$(prompt_bool "Ryujinx (Switch emulator)" "$DEF_RYUJINX")
        if [[ "$NEW_RYUJINX" != "$DEF_RYUJINX" ]]; then
            HM_OVERRIDES+=$'\n  applications.games.ryujinx.enable = '"$NEW_RYUJINX"';'
        fi
        echo ""

        # ==============================================================
        # HM Services
        # ==============================================================
        header "Services (Home Manager)"

        DEF_COMPANION="false"
        NEW_COMPANION=$(prompt_bool "Companion (Claude Code Web UI)" "$DEF_COMPANION")
        if [[ "$NEW_COMPANION" != "$DEF_COMPANION" ]]; then
            HM_OVERRIDES+=$'\n  services.companion.enable = '"$NEW_COMPANION"';'
        fi
        echo ""

        DEF_CLAUDE_MCP="true"
        NEW_CLAUDE_MCP=$(prompt_bool "Claude MCP servers" "$DEF_CLAUDE_MCP")
        if [[ "$NEW_CLAUDE_MCP" != "$DEF_CLAUDE_MCP" ]]; then
            HM_OVERRIDES+=$'\n  services.claude-mcp.enable = '"$NEW_CLAUDE_MCP"';'
        fi
        echo ""

        DEF_WHISPER="true"
        NEW_WHISPER=$(prompt_bool "Whisper STT (speech to text)" "$DEF_WHISPER")
        if [[ "$NEW_WHISPER" != "$DEF_WHISPER" ]]; then
            HM_OVERRIDES+=$'\n  services.whisperStt.enable = '"$NEW_WHISPER"';'
        fi
        echo ""

        # Cyber (HM)
        header "Cyber (Home Manager)"

        DEF_HM_MALWARE="false"
        NEW_HM_MALWARE=$(prompt_bool "Malware analysis tools" "$DEF_HM_MALWARE")
        if [[ "$NEW_HM_MALWARE" != "$DEF_HM_MALWARE" ]]; then
            HM_OVERRIDES+=$'\n  cyber.malwareAnalysis.enable = '"$NEW_HM_MALWARE"';'
        fi
        echo ""

        # --- Write the HM host file ---
        HM_HOST_DIR="$SCRIPT_DIR/users/$INSTALL_USER/hosts"
        mkdir -p "$HM_HOST_DIR"

        cat > "$HM_HOST_DIR/$HOSTNAME.nix" << HMEOF
{...}: {
  imports = [./default.nix];

  # Override only what's different from the default${HM_OVERRIDES}
}
HMEOF

        fix_owner "$HM_HOST_DIR/$HOSTNAME.nix"
        ok "Created $HM_HOST_DIR/$HOSTNAME.nix"
        echo ""

    else
        warn "HM defaults file not found at $HM_DEFAULTS_FILE — skipping Home Manager host generation."
        echo ""
    fi

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
    if [[ -f "$SCRIPT_DIR/users/$INSTALL_USER/hosts/$HOSTNAME.nix" ]]; then
        cmd "cat $SCRIPT_DIR/users/$INSTALL_USER/hosts/$HOSTNAME.nix"
    fi
    echo ""
fi

# Set HOST_DIR for the rest of the script
HOST_DIR="$SCRIPT_DIR/hosts/$HOSTNAME"

if [[ ! -d "$HOST_DIR" ]]; then
    err "Host directory $HOST_DIR does not exist."
    exit 1
fi

# Config destination on the mounted target system
CONFIG_DEST="/mnt/home/$INSTALL_USER/.nixos"

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
echo -e "  Config dest:    ${BOLD}$CONFIG_DEST${NC}"
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

    STEP=1

    info "${BOLD}Step $STEP: Create hardware-configuration.nix stub (if missing)${NC}"
    echo -e "  ${DIM}(Needed so disko can evaluate the NixOS configuration)${NC}"
    cmd "test -f '${HW_CONFIG}' || cat > '${HW_CONFIG}' << 'STUBEOF'"
    echo -e "  ${GREEN}{lib, ...}: {${NC}"
    echo -e "  ${GREEN}  # Stub - will be regenerated after disk formatting${NC}"
    echo -e "  ${GREEN}  nixpkgs.hostPlatform = lib.mkDefault \"x86_64-linux\";${NC}"
    echo -e "  ${GREEN}}${NC}"
    echo -e "  ${GREEN}STUBEOF${NC}"
    cmd "sudo chown $REPO_OWNER '${HW_CONFIG}'"
    echo ""
    ((STEP++))

    info "${BOLD}Step $STEP: Format, encrypt, and mount the disk with disko${NC}"
    echo -e "  ${RED}WARNING: This will DESTROY all data on /dev/$DEVICE${NC}"
    echo ""
    cmd "sudo nix --experimental-features 'nix-command flakes' \\"
    echo -e "    ${GREEN}run github:nix-community/disko/latest -- \\${NC}"
    echo -e "    ${GREEN}--mode destroy,format,mount \\${NC}"
    echo -e "    ${GREEN}--flake '${SCRIPT_DIR}#${HOSTNAME}'${NC}"
    echo ""
    ((STEP++))

    info "${BOLD}Step $STEP: Verify mounts and swap${NC}"
    cmd "mount | grep /mnt"
    cmd "swapon --show"
    echo ""
    ((STEP++))

    if [[ "$GENERATE_HW" == "true" ]]; then
        info "${BOLD}Step $STEP: Generate hardware configuration${NC}"
        cmd "sudo nixos-generate-config --no-filesystems --root /mnt --show-hardware-config > ${HW_CONFIG}"
        cmd "sudo chown $REPO_OWNER '${HW_CONFIG}'"
        echo ""
        ((STEP++))
    fi

    info "${BOLD}Step $STEP: Copy config and prepare for flake evaluation${NC}"
    cmd "sudo mkdir -p '$CONFIG_DEST'"
    cmd "sudo cp -r ${SCRIPT_DIR}/. '$CONFIG_DEST/'"
    cmd "sudo chown -R $REPO_OWNER '$CONFIG_DEST'"
    cmd "cd '$CONFIG_DEST' && sudo git init -q && sudo git add -A"
    echo ""
    ((STEP++))

    info "${BOLD}Step $STEP: (Optional) Pre-build the closure to catch errors${NC}"
    if [[ $TOTAL_RAM_GB -le 8 ]]; then
        cmd "nix build '${CONFIG_DEST}#nixosConfigurations.${HOSTNAME}.config.system.build.toplevel' \\"
        echo -e "    ${GREEN}--no-link --option max-jobs 2 --option cores 2${NC}"
    else
        cmd "nix build '${CONFIG_DEST}#nixosConfigurations.${HOSTNAME}.config.system.build.toplevel' --no-link"
    fi
    echo ""
    ((STEP++))

    info "${BOLD}Step $STEP: Install NixOS${NC}"
    if [[ $TOTAL_RAM_GB -le 8 ]]; then
        cmd "sudo nixos-install --root /mnt \\"
        echo -e "    ${GREEN}--flake '${CONFIG_DEST}#${HOSTNAME}' \\${NC}"
        echo -e "    ${GREEN}--no-channel-copy --no-root-passwd \\${NC}"
        echo -e "    ${GREEN}--option max-jobs 2 --option cores 2${NC}"
    else
        cmd "sudo nixos-install --root /mnt \\"
        echo -e "    ${GREEN}--flake '${CONFIG_DEST}#${HOSTNAME}' \\${NC}"
        echo -e "    ${GREEN}--no-channel-copy --no-root-passwd${NC}"
    fi
    echo ""
    ((STEP++))

    info "${BOLD}Step $STEP: Reboot${NC}"
    cmd "sudo reboot"
    echo ""

    info "${BOLD}Recovery (if install fails partway — don't reformat):${NC}"
    cmd "sudo nix run github:nix-community/disko/latest -- \\"
    echo -e "    ${GREEN}--mode mount --flake '${SCRIPT_DIR}#${HOSTNAME}'${NC}"
    cmd "sudo nixos-install --root /mnt --flake '${CONFIG_DEST}#${HOSTNAME}' --no-channel-copy --no-root-passwd"
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
# Step 8: Create hardware-configuration.nix stub (if missing)
# ---------------------------------------------------------------------------

if [[ ! -f "$HW_CONFIG" ]]; then
    info "Creating hardware-configuration.nix stub for disko evaluation..."
    cat > "$HW_CONFIG" << 'STUBEOF'
{lib, ...}: {
  # Stub — will be regenerated after disk formatting
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
STUBEOF
    fix_owner "$HW_CONFIG"
    ok "Created stub $HW_CONFIG"
    echo ""
fi

# ---------------------------------------------------------------------------
# Step 9: Run disko (format + mount)
# ---------------------------------------------------------------------------

info "Running disko: destroy, format, and mount /dev/$DEVICE..."
echo ""

if ! nix --experimental-features "nix-command flakes" \
    run github:nix-community/disko/latest -- \
    --mode destroy,format,mount \
    --flake "$SCRIPT_DIR#$HOSTNAME"; then
    err "Disko formatting failed. Check the output above."
    err "If the disk was partially formatted, you can try recovery:"
    cmd "sudo nix run github:nix-community/disko/latest -- --mode mount --flake '$SCRIPT_DIR#$HOSTNAME'"
    exit 1
fi

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
# Step 10: Generate hardware config (if needed)
# ---------------------------------------------------------------------------

if [[ "$GENERATE_HW" == "true" ]]; then
    info "Generating hardware configuration..."
    nixos-generate-config --no-filesystems --root /mnt --show-hardware-config > "$HW_CONFIG"
    fix_owner "$HW_CONFIG"
    ok "Hardware config written to $HW_CONFIG"
    echo ""
fi

# ---------------------------------------------------------------------------
# Step 11: Copy config to mounted system and prepare for flake eval
# ---------------------------------------------------------------------------

info "Copying configuration to $CONFIG_DEST..."
mkdir -p "$CONFIG_DEST"
cp -r "$SCRIPT_DIR"/. "$CONFIG_DEST/"
fix_owner "$CONFIG_DEST"
# Flakes only see git-tracked files — init a repo and stage everything
(cd "$CONFIG_DEST" && git init -q && git add -A)
fix_owner "$CONFIG_DEST"
ok "Configuration copied and staged for flake evaluation."
echo ""

# ---------------------------------------------------------------------------
# Step 12: Pre-build the closure (optional, catches config errors early)
# ---------------------------------------------------------------------------

if confirm_yes "Pre-build the system closure? (catches config errors before writing to disk)"; then
    echo ""
    info "Building system closure..."

    BUILD_ARGS=()
    if [[ $TOTAL_RAM_GB -le 8 ]]; then
        warn "Low RAM: limiting build parallelism (max-jobs=2, cores=2)."
        BUILD_ARGS+=(--option max-jobs 2 --option cores 2)
    fi

    if nix build "$CONFIG_DEST#nixosConfigurations.$HOSTNAME.config.system.build.toplevel" \
        --no-link "${BUILD_ARGS[@]}"; then
        ok "System closure built successfully."
    else
        err "Build failed. Fix the errors above before continuing."
        echo ""
        if ! confirm "Continue with nixos-install anyway?"; then
            info "Aborted. The disk is formatted and mounted at /mnt."
            info "Fix the config, then re-run:"
            cmd "sudo nixos-install --root /mnt --flake '$CONFIG_DEST#$HOSTNAME' --no-channel-copy --no-root-passwd"
            exit 1
        fi
    fi
    echo ""
fi

# ---------------------------------------------------------------------------
# Step 13: Install NixOS
# ---------------------------------------------------------------------------

info "Installing NixOS..."
echo ""

INSTALL_ARGS=(
    --root /mnt
    --flake "$CONFIG_DEST#$HOSTNAME"
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
# Step 14: Post-install info
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
cmd "sudo nixos-install --root /mnt --flake '$CONFIG_DEST#$HOSTNAME' --no-channel-copy --no-root-passwd"
echo ""
