#!/usr/bin/env bash
# dfir-create-base — build a clean Windows "BUILD-READY" base VM for the FLARE
# pipeline, unattended, from a Windows ISO. See usage() for the interface.
#
# ponytail: the from-ISO base is the least reproducible link in the chain
# (Win11 edition/product-key, disk layout, and the Defender/Tamper disable
# sequence all vary by ISO). Treat this as a first-draft you tune on a real
# host, not a proven artifact. Guest Additions + Defender disable happen in
# autounattend FirstLogonCommands, which are the parts most likely to need it.
set -euo pipefail

usage() {
    cat <<'EOF'
dfir-create-base — build a clean Windows "BUILD-READY" base VM for the FLARE
pipeline, unattended, from a Windows ISO.

  dfir-create-base <windows.iso> [vm-name] [--wait]

Produces a registered VM that installs Windows via autounattend.xml (local
admin flare/password, UAC off, Defender/Tamper best-effort off, VirtualBox
Guest Additions installed), powers itself off, and — with --wait — is
snapshotted as "BUILD-READY", the entry point vbox-build-flare-vm expects.
The vm-name defaults to DFIR-BUILD-BASE; dfir-prepare-variant clones it into
the per-variant VMs the build scripts look for.

Options via env: DFIR_RAM DFIR_CPUS DFIR_DISK_GB DFIR_AUTOUNATTEND
                 DFIR_WAIT=1 (same as --wait) DFIR_INSTALL_TIMEOUT
EOF
    exit "${1:-0}"
}

RAM="${DFIR_RAM:-8192}"
CPUS="${DFIR_CPUS:-4}"
DISK_GB="${DFIR_DISK_GB:-120}"
AUTOUNATTEND="${DFIR_AUTOUNATTEND:-$HOME/.config/dfir/windows/autounattend.xml}"
WAIT_FOR_SNAPSHOT="${DFIR_WAIT:-0}"
INSTALL_TIMEOUT="${DFIR_INSTALL_TIMEOUT:-3600}" # seconds to wait for poweroff

# --wait is positional-free: accept it anywhere in the argument list.
positional=()
for arg in "$@"; do
    case "$arg" in
    --wait) WAIT_FOR_SNAPSHOT=1 ;;
    --help | -h) usage ;;
    -*)
        echo "error: unknown option '$arg'" >&2
        usage 1
        ;;
    *) positional+=("$arg") ;;
    esac
done
WIN_ISO="${positional[0]:-}"
NAME="${positional[1]:-DFIR-BUILD-BASE}"
[[ -n "$WIN_ISO" ]] || usage 1

command -v VBoxManage >/dev/null || {
    echo "error: VBoxManage not found — is cyber.dfir.enable set and are you in vboxusers?" >&2
    exit 1
}
[[ -f "$WIN_ISO" ]] || {
    echo "error: Windows ISO not found: $WIN_ISO" >&2
    exit 1
}
[[ -f "$AUTOUNATTEND" ]] || {
    echo "error: autounattend not found: $AUTOUNATTEND" >&2
    exit 1
}
if VBoxManage showvminfo "$NAME" >/dev/null 2>&1; then
    echo "error: VM '$NAME' already exists — delete it first: VBoxManage unregistervm '$NAME' --delete" >&2
    exit 1
fi

# Guest Additions ISO that ships with the installed VirtualBox.
GA_ISO="$(VBoxManage list systemproperties | sed -n 's/^Default Guest Additions ISO: *//p')"
MACHINE_FOLDER="$(VBoxManage list systemproperties | sed -n 's/^Default machine folder: *//p')"
DISK="$MACHINE_FOLDER/$NAME/$NAME.vdi"

# Windows setup scans all attached media for autounattend.xml — carry it (and
# any helper files) on a tiny ISO built with xorriso.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/src"
cp "$AUTOUNATTEND" "$WORK/src/autounattend.xml"
UNATTEND_ISO="$WORK/unattend.iso"
xorriso -as mkisofs -quiet -J -R -V UNATTEND -o "$UNATTEND_ISO" "$WORK/src"

echo "[*] Creating VM '$NAME' ($RAM MiB, $CPUS vCPU, ${DISK_GB}G disk)"
VBoxManage createvm --name "$NAME" --ostype Windows11_64 --register
VBoxManage modifyvm "$NAME" \
    --memory "$RAM" --cpus "$CPUS" --vram 128 \
    --firmware efi --chipset ich9 \
    --graphicscontroller vboxsvga \
    --nic1 nat \
    --clipboard-mode disabled --draganddrop disabled \
    --audio-driver none
# Win11 requirements: vTPM 2.0 + secure boot capable. Bypasses in the
# autounattend cover hosts where these still trip setup.
VBoxManage modifyvm "$NAME" --tpm-type 2.0 || echo "  (warning: --tpm-type unsupported; autounattend bypass must cover it)"

VBoxManage createmedium disk --filename "$DISK" --size "$((DISK_GB * 1024))" --format VDI
VBoxManage storagectl "$NAME" --name SATA --add sata --controller IntelAhci --portcount 4 --bootable on
VBoxManage storageattach "$NAME" --storagectl SATA --port 0 --device 0 --type hdd --medium "$DISK"
VBoxManage storageattach "$NAME" --storagectl SATA --port 1 --device 0 --type dvddrive --medium "$WIN_ISO"
VBoxManage storageattach "$NAME" --storagectl SATA --port 2 --device 0 --type dvddrive --medium "$UNATTEND_ISO"
if [[ -f "$GA_ISO" ]]; then
    VBoxManage storageattach "$NAME" --storagectl SATA --port 3 --device 0 --type dvddrive --medium "$GA_ISO"
else
    echo "  (warning: Guest Additions ISO not found at '$GA_ISO' — GA install in autounattend will be skipped)"
fi

echo "[*] Booting unattended install…"
VBoxManage startvm "$NAME" --type gui

if [[ "$WAIT_FOR_SNAPSHOT" != "1" ]]; then
    cat <<EOF

[*] Windows is installing unattended. When the VM powers itself off, snapshot it:

    VBoxManage snapshot "$NAME" take BUILD-READY \\
        --description "clean Windows, UAC/Defender off, GA installed"

Then build a lab VM from it (see ~/.config/dfir/README.md):
    dfir-prepare-variant dfir
    vbox-build-flare-vm ~/.config/dfir/variants/dfir.yaml --custom_config
EOF
    exit 0
fi

echo "[*] Waiting up to $INSTALL_TIMEOUT s for the install to finish (VM poweroff)…"
elapsed=0
while true; do
    state="$(VBoxManage showvminfo "$NAME" --machinereadable | sed -n 's/^VMState="\(.*\)"/\1/p')"
    case "$state" in
    poweroff | saved)
        echo "[*] VM powered off — taking BUILD-READY snapshot"
        VBoxManage snapshot "$NAME" take BUILD-READY \
            --description "clean Windows, UAC/Defender off, GA installed"
        echo "[+] Done. Next: dfir-prepare-variant dfir  (clones this base + stages config.xml)"
        exit 0
        ;;
    aborted)
        echo "error: VM aborted during install — inspect it, no snapshot taken" >&2
        exit 1
        ;;
    esac
    ((elapsed += 15))
    if ((elapsed >= INSTALL_TIMEOUT)); then
        echo "error: timed out after $INSTALL_TIMEOUT s; VM state is '$state'. Snapshot manually once it powers off." >&2
        exit 1
    fi
    sleep 15
done
