#!/usr/bin/env bash
# dfir-prepare-variant — bridge the base VM to what vbox-build-flare-vm expects.
#
# The base VM built by dfir-create-base is one VM named DFIR-BUILD-BASE, but
# each variant's build wants its own VM (variants/*.yaml VM_NAME) carrying its
# own BUILD-READY snapshot, and reads its FLARE config from the fixed path
# ~/FLARE-VM REQUIRED FILES/config.xml. This closes both gaps.
set -euo pipefail

DFIR_DIR="${DFIR_DIR:-$HOME/.config/dfir}"
REQUIRED_FILES="$HOME/FLARE-VM REQUIRED FILES" # hardcoded in vbox-build-flare-vm.py
BASE_VM="${DFIR_BASE_VM:-DFIR-BUILD-BASE}"
SNAPSHOT=BUILD-READY

usage() {
    cat <<EOF
Usage: dfir-prepare-variant <dfir|malware>

Clones $BASE_VM@$SNAPSHOT into the variant's VM_NAME (if absent), re-takes the
$SNAPSHOT snapshot on the clone, and stages the variant's FLARE config +
updater into "$REQUIRED_FILES" (which the build copies to the guest Desktop).

Env: DFIR_BASE_VM (default $BASE_VM), DFIR_DIR (default \$HOME/.config/dfir).
EOF
    exit "${1:-0}"
}

[[ $# -eq 1 ]] || usage 1
case "$1" in --help | -h) usage ;; esac
variant="$1"

VARIANT_YAML="$DFIR_DIR/variants/$variant.yaml"
CONFIG_XML="$DFIR_DIR/config/$variant-config.xml"
MANIFEST="$DFIR_DIR/manifests/$variant-tools.yaml"
for f in "$VARIANT_YAML" "$CONFIG_XML" "$MANIFEST"; do
    [[ -f "$f" ]] || {
        echo "error: missing $f" >&2
        exit 1
    }
done

VM_NAME="$(sed -n 's/^VM_NAME: *//p' "$VARIANT_YAML")"
[[ -n "$VM_NAME" ]] || {
    echo "error: no VM_NAME in $VARIANT_YAML" >&2
    exit 1
}

if VBoxManage showvminfo "$VM_NAME" >/dev/null 2>&1; then
    echo "[=] VM '$VM_NAME' already exists — leaving it alone."
else
    VBoxManage showvminfo "$BASE_VM" >/dev/null 2>&1 || {
        echo "error: base VM '$BASE_VM' not found — run dfir-create-base first." >&2
        exit 1
    }
    echo "[*] Cloning $BASE_VM@$SNAPSHOT -> $VM_NAME"
    # --mode machine clones only the snapshot's state: the clone has no
    # snapshots of its own, so the build's restore would fail without the
    # re-take below.
    VBoxManage clonevm "$BASE_VM" --snapshot "$SNAPSHOT" --mode machine \
        --name "$VM_NAME" --register
fi

if VBoxManage snapshot "$VM_NAME" list --machinereadable 2>/dev/null |
    grep -qx "SnapshotName=\"$SNAPSHOT\""; then
    echo "[=] '$VM_NAME' already has a $SNAPSHOT snapshot."
else
    echo "[*] Taking $SNAPSHOT on $VM_NAME"
    VBoxManage snapshot "$VM_NAME" take "$SNAPSHOT" \
        --description "clean Windows base for $variant"
fi

# The build copies this directory into the guest Desktop, then runs install.ps1
# with -customConfig '<Desktop>\config.xml'. Only our three managed filenames
# are written, so anything else you keep here survives.
echo "[*] Staging FLARE inputs in $REQUIRED_FILES"
mkdir -p "$REQUIRED_FILES"
install -m644 "$CONFIG_XML" "$REQUIRED_FILES/config.xml"
install -m644 "$DFIR_DIR/windows/update-tools.ps1" "$REQUIRED_FILES/update-tools.ps1"
install -m644 "$MANIFEST" "$REQUIRED_FILES/tools.yaml" # update-tools.ps1's default

cat <<EOF

[+] '$VM_NAME' ready. Build it:
    vbox-build-flare-vm $VARIANT_YAML --custom_config
EOF
if [[ "$variant" == malware ]]; then
    echo "    dfir-vm-network malware '$VM_NAME'   # BEFORE any detonation"
fi
