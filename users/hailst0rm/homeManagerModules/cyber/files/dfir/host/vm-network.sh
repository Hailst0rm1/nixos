#!/usr/bin/env bash
# dfir-vm-network — apply the DFIR lab network model to VirtualBox VMs.
#
# Two trust zones:
#   DFIR VM      -> NAT (internet + updates), normal integrations.
#   Malware VM   -> internal network "malware-net", fully isolated:
#                   no host, no forwarding, no clipboard/drag-drop/USB.
#   REMnux (opt) -> same malware-net, to offer simulated services.
#
# Idempotent: safe to re-run. VirtualBox internal networks need no creation —
# a NIC simply names the intnet it belongs to.
set -euo pipefail

INTNET="${DFIR_MALWARE_NET:-malware-net}"

usage() {
    cat <<EOF
Usage: dfir-vm-network <command> <vm-name>

Commands:
  dfir     <vm>   NAT + bidirectional clipboard/drag-drop (trusted).
  malware  <vm>   Isolate on internal net "$INTNET", strip all host bridges.
  status   <vm>   Show the VM's current NIC/clipboard/USB settings.

Env:
  DFIR_MALWARE_NET   Internal network name (default: malware-net).
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

case "$cmd" in
dfir)
    VBoxManage modifyvm "$vm" \
        --nic1 nat \
        --clipboard-mode bidirectional \
        --draganddrop hosttoguest
    echo "[+] '$vm' set to NAT (trusted DFIR)."
    ;;
malware)
    VBoxManage modifyvm "$vm" \
        --nic1 intnet --intnet1 "$INTNET" --cableconnected1 on \
        --nic2 none --nic3 none --nic4 none \
        --clipboard-mode disabled \
        --draganddrop disabled \
        --usb off --usbehci off --usbxhci off
    echo "[+] '$vm' isolated on internal net '$INTNET' (untrusted malware)."
    echo "    No forwarding: attach REMnux to '$INTNET' for simulated services."
    ;;
status)
    VBoxManage showvminfo "$vm" | grep -iE 'NIC [0-9]|Clipboard|Drag|^USB' || true
    ;;
*) usage 1 ;;
esac
