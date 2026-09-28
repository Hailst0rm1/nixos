#!/usr/bin/env bash
# dfir-vm-network — apply the DFIR lab trust model to VirtualBox VMs.
#
# Two trust zones:
#   DFIR VM      -> NAT (internet + updates), normal integrations.
#   Malware VM   -> internal network "malware-net", fully isolated:
#                   no host, no forwarding, no clipboard/drag-drop/USB,
#                   plus a non-VirtualBox hardware identity.
#   REMnux (opt) -> same malware-net, to offer simulated services.
#
# Idempotent: safe to re-run. VirtualBox internal networks need no creation —
# a NIC simply names the intnet it belongs to, and the spoofed hardware
# identity is derived from the VM name rather than randomised per run.
set -euo pipefail

INTNET="${DFIR_MALWARE_NET:-malware-net}"
SPOOF_OUI="${DFIR_SPOOF_OUI:-001422}" # Dell Inc., to match the DMI values below

usage() {
    cat <<EOF
Usage: dfir-vm-network <command> <vm-name>

Commands:
  dfir     <vm>   NAT + bidirectional clipboard/drag-drop (trusted).
  malware  <vm>   Isolate on internal net "$INTNET", strip all host bridges,
                  and overwrite the VirtualBox hardware identity (DMI/SMBIOS,
                  disk model+serial, MAC OUI).
  unspoof  <vm>   Drop the hardware overrides again. Use this first if a VM
                  stops booting after 'malware'.
  status   <vm>   Show current NIC/clipboard/USB and spoofed identity.

The VM must be powered off for 'dfir', 'malware' and 'unspoof'.

Env:
  DFIR_MALWARE_NET   Internal network name (default: malware-net).
  DFIR_SPOOF_OUI     MAC OUI, 6 hex digits (default: 001422, Dell).
EOF
    exit "${1:-0}"
}

[[ $# -eq 2 ]] || usage 1
cmd="$1"
vm="$2"

VBoxManage showvminfo "$vm" >/dev/null 2>&1 || {
    echo "error: VM '$vm' not found" >&2
    exit 1
}

require_poweroff() {
    local state
    state="$(VBoxManage showvminfo "$vm" --machinereadable | sed -n 's/^VMState="\(.*\)"/\1/p')"
    case "$state" in
    poweroff | saved | aborted) ;;
    *)
        echo "error: '$vm' is '$state'; VBoxManage cannot change settings on a" >&2
        echo "       running VM. Shut it down first:" >&2
        echo "         VBoxManage controlvm '$vm' acpipowerbutton" >&2
        exit 1
        ;;
    esac
}

# A stable per-VM hardware identity. Hashing the VM name keeps re-runs
# idempotent (a fresh random serial on every invocation would itself look odd)
# while still giving each VM its own.
hw_ident() { printf '%s' "$vm" | md5sum | cut -c1-12 | tr 'a-f' 'A-F'; }

# VirtualBox publishes its own name through SMBIOS/DMI and through the virtual
# disk's identity strings. Reading those is the cheapest sandbox check there
# is, so a detonation box overwrites them with one consistent real-vendor
# identity. Ports 1-3 are the DVD drives; port 0 is the system disk.
#
# ponytail: static identifiers only. Guest Additions (VBoxService.exe, the
# VBox* drivers and their registry keys) stay visible and are a far stronger
# tell -- uninstall them inside the guest once the FLARE build no longer needs
# host-driven automation.
hw_keys() {
    local serial="$1"
    cat <<EOF
VBoxInternal/Devices/pcbios/0/Config/DmiBIOSVendor=Dell Inc.
VBoxInternal/Devices/pcbios/0/Config/DmiBIOSVersion=2.18.1
VBoxInternal/Devices/pcbios/0/Config/DmiBIOSReleaseDate=09/18/2023
VBoxInternal/Devices/pcbios/0/Config/DmiSystemVendor=Dell Inc.
VBoxInternal/Devices/pcbios/0/Config/DmiSystemProduct=OptiPlex 7090
VBoxInternal/Devices/pcbios/0/Config/DmiSystemVersion=1.0
VBoxInternal/Devices/pcbios/0/Config/DmiSystemFamily=OptiPlex
VBoxInternal/Devices/pcbios/0/Config/DmiSystemSerial=$serial
VBoxInternal/Devices/pcbios/0/Config/DmiBoardVendor=Dell Inc.
VBoxInternal/Devices/pcbios/0/Config/DmiBoardProduct=0J37VM
VBoxInternal/Devices/pcbios/0/Config/DmiBoardVersion=A01
VBoxInternal/Devices/pcbios/0/Config/DmiBoardSerial=$serial
VBoxInternal/Devices/pcbios/0/Config/DmiChassisVendor=Dell Inc.
VBoxInternal/Devices/pcbios/0/Config/DmiChassisType=3
VBoxInternal/Devices/pcbios/0/Config/DmiChassisVersion=A01
VBoxInternal/Devices/pcbios/0/Config/DmiChassisSerial=$serial
VBoxInternal/Devices/pcbios/0/Config/DmiOEMVBoxVer=Dell System
VBoxInternal/Devices/pcbios/0/Config/DmiOEMVBoxRev=A01
VBoxInternal/Devices/ahci/0/Config/Port0/ModelNumber=SAMSUNG MZVLB512HBJQ-000L7
VBoxInternal/Devices/ahci/0/Config/Port0/SerialNumber=S4ENNF0M$serial
VBoxInternal/Devices/ahci/0/Config/Port0/FirmwareRevision=4L2QEXA7
EOF
}

case "$cmd" in
dfir)
    require_poweroff
    VBoxManage modifyvm "$vm" \
        --nic1 nat \
        --clipboard-mode bidirectional \
        --draganddrop hosttoguest
    echo "[+] '$vm' set to NAT (trusted DFIR)."
    ;;
malware)
    require_poweroff
    VBoxManage modifyvm "$vm" \
        --nic1 intnet --intnet1 "$INTNET" --cableconnected1 on \
        --nic2 none --nic3 none --nic4 none \
        --clipboard-mode disabled \
        --draganddrop disabled \
        --usb off --usbehci off --usbxhci off

    # A shared folder is a live path from the detonation box to the host
    # filesystem, so isolation is not isolation while one exists.
    while read -r folder; do
        [[ -n "$folder" ]] || continue
        echo "[*] Removing shared folder '$folder'"
        VBoxManage sharedfolder remove "$vm" --name "$folder"
    done < <(VBoxManage showvminfo "$vm" --machinereadable |
        sed -n 's/^SharedFolderNameMachineMapping[0-9]*="\(.*\)"$/\1/p')

    ident="$(hw_ident)"
    VBoxManage modifyvm "$vm" --macaddress1 "${SPOOF_OUI}${ident:0:6}"
    while IFS='=' read -r key value; do
        [[ -n "$key" ]] || continue
        VBoxManage setextradata "$vm" "$key" "$value"
    done < <(hw_keys "${ident:0:7}")

    echo "[+] '$vm' isolated on internal net '$INTNET' (untrusted malware)."
    echo "    No forwarding: attach REMnux to '$INTNET' for simulated services."
    echo "[+] Hardware identity spoofed: Dell OptiPlex 7090, MAC ${SPOOF_OUI}${ident:0:6}."
    echo "    Guest Additions are still visible in the guest -- remove them there"
    echo "    before detonating anything that checks."
    ;;
unspoof)
    require_poweroff
    while IFS='=' read -r key _; do
        [[ -n "$key" ]] || continue
        VBoxManage setextradata "$vm" "$key" # no value = delete
    done < <(hw_keys placeholder)
    echo "[+] Hardware overrides removed from '$vm'. The MAC is left alone;"
    echo "    reset it with: VBoxManage modifyvm '$vm' --macaddress1 auto"
    ;;
status)
    VBoxManage showvminfo "$vm" | grep -iE 'NIC [0-9]|Clipboard|Drag|^USB' || true
    echo "--- spoofed hardware identity ---"
    VBoxManage getextradata "$vm" enumerate | grep -i "VBoxInternal/Devices" ||
        echo "(none set -- this VM reports itself as VirtualBox)"
    ;;
*) usage 1 ;;
esac
