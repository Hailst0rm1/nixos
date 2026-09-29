#!/usr/bin/env bash
# dfir-lab — the whole lab build pipeline. No arguments runs an interactive
# wizard; flags run the same stages non-interactively (for agents/scripts):
#
#   1. base     unattended Windows install from ISO -> DFIR-BUILD-BASE@BUILD-READY
#   2. Defender the one manual step (Tamper Protection), verified in the guest
#   3. variant  clone the base per variant + stage its FLARE inputs
#   4. build    vbox-build-flare-vm
#   5. network  dfir-vm-network (the malware VM's isolation is not optional)
#
# Every stage looks at what already exists first, and only deletes a VM after
# an explicit yes (the wizard asks; in flag mode --rebuild/--reclone are the yes).
#
# ponytail: the from-ISO base is the least reproducible link in the chain
# (Win11 edition/product-key, disk layout, and the Defender/Tamper disable
# sequence all vary by ISO). Treat it as a first-draft you tune on a real
# host, not a proven artifact.
set -euo pipefail

DFIR_DIR="${DFIR_DIR:-$HOME/.config/dfir}"
BASE_VM="${DFIR_BASE_VM:-DFIR-BUILD-BASE}"
SNAPSHOT="BUILD-READY"
# Must match the path pkgs/flare-vbox patches into vbox-build-flare-vm.py.
REQUIRED_FILES="$HOME/.local/share/dfir/flare-vm-required-files"
# Guest account from windows/autounattend.xml (and pkgs/flare-vbox guestUsername).
GUEST_USER=jsmith
GUEST_PASS=password
# The base's snapshot is re-taken with this description once Defender is off;
# it is how a later run knows the manual step was done.
DEFENDER_OFF="clean Windows, UAC/Defender/Tamper off, GA installed"

RAM="${DFIR_RAM:-8192}"
CPUS="${DFIR_CPUS:-4}"
DISK_GB="${DFIR_DISK_GB:-120}"
AUTOUNATTEND="${DFIR_AUTOUNATTEND:-$DFIR_DIR/windows/autounattend.xml}"
INSTALL_TIMEOUT="${DFIR_INSTALL_TIMEOUT:-3600}" # seconds to wait for poweroff

usage() {
    cat <<EOF
dfir-lab — Windows ISO -> base VM -> FLARE-built lab VMs.

  dfir-lab            interactive wizard (asks at every decision)
  dfir-lab [flags]    run only the given stages, in pipeline order, no prompts

Stages:
  --status                  print base/variant state as key=value lines, then exit
  --base                    ensure the base VM + $SNAPSHOT snapshot exist
    --iso <path>            Windows ISO for a new base (implies --base)
    --rebuild               delete and recreate an existing base
  --defender                ensure Defender is off on the base. Needs a human:
                            starts the base, prints the GPO steps and exits 3;
                            re-run once they are done to verify + re-snapshot
  --variant <dfir|malware|both>
                            clone (if absent) + stage + build + apply network
    --reclone               delete and re-clone an existing variant VM
    --resume                finish from the VM's last <name>.<date>.base
                            snapshot instead of re-running the FLARE install
    --no-build              stop after cloning/staging

Exit: 0 ok, 1 error, 3 waiting on the manual Defender step.
Env: DFIR_BASE_VM (default DFIR-BUILD-BASE), DFIR_DIR (default ~/.config/dfir),
     DFIR_RAM DFIR_CPUS DFIR_DISK_GB DFIR_AUTOUNATTEND DFIR_INSTALL_TIMEOUT
EOF
    exit "${1:-0}"
}

INTERACTIVE=1 STATUS=0 DO_BASE=0 DO_DEFENDER=0 REBUILD=0 RECLONE=0 RESUME=0 BUILD=1 ISO=""
VARIANTS=()
(($# == 0)) || INTERACTIVE=0
while (($#)); do
    case "$1" in
    --status) STATUS=1 ;;
    --base) DO_BASE=1 ;;
    --iso)
        [[ $# -ge 2 ]] || usage 1
        ISO="$2" DO_BASE=1
        shift
        ;;
    --rebuild) REBUILD=1 ;;
    --defender) DO_DEFENDER=1 ;;
    --variant)
        case "${2:-}" in
        dfir | malware) VARIANTS+=("$2") ;;
        both) VARIANTS+=(dfir malware) ;;
        *) usage 1 ;;
        esac
        shift
        ;;
    --reclone) RECLONE=1 ;;
    --resume) RESUME=1 ;;
    --no-build) BUILD=0 ;;
    -h | --help) usage 0 ;;
    *)
        echo "error: unknown argument '$1'" >&2
        usage 1
        ;;
    esac
    shift
done

die() {
    echo "error: $*" >&2
    exit 1
}
confirm() {
    local a
    read -rp "$1 [y/N] " a
    [[ "$a" == [yY]* ]]
}
# decide "question" <flag>: the wizard asks; flag mode takes the flag's answer.
decide() {
    if ((INTERACTIVE)); then confirm "$1"; else (($2)); fi
}
# choose "prompt" a b c -> echoes the first letter picked, re-asks until valid.
choose() {
    local prompt="$1" a
    shift
    while true; do
        read -rp "$prompt " a
        for opt in "$@"; do [[ "$a" == "$opt" ]] && echo "$a" && return; done
    done
}
vm_exists() { VBoxManage showvminfo "$1" >/dev/null 2>&1; }
vm_state() { VBoxManage showvminfo "$1" --machinereadable | sed -n 's/^VMState="\(.*\)"/\1/p'; }
snapshot_names() { VBoxManage snapshot "$1" list --machinereadable 2>/dev/null | sed -n 's/^SnapshotName[-0-9]*="\(.*\)"$/\1/p'; }
has_snapshot() { snapshot_names "$1" | grep -qxF "$2"; }
# Description of the top-level snapshot, which is BUILD-READY on the base.
base_snapshot_desc() { VBoxManage snapshot "$1" list --machinereadable 2>/dev/null | sed -n 's/^SnapshotDescription="\(.*\)"$/\1/p'; }
is_off() { [[ "$(vm_state "$1")" =~ ^(poweroff|saved|aborted)$ ]]; }

# Returns 1 on timeout or if the VM aborted.
wait_poweroff() {
    local vm="$1" timeout="$2" elapsed=0 state
    echo "[*] Waiting up to $timeout s for '$vm' to power off…"
    while true; do
        state="$(vm_state "$vm")"
        case "$state" in
        poweroff | saved) return 0 ;;
        aborted)
            echo "error: '$vm' aborted" >&2
            return 1
            ;;
        esac
        ((elapsed += 15))
        ((elapsed < timeout)) || {
            echo "error: timed out; '$vm' is '$state'" >&2
            return 1
        }
        sleep 15
    done
}

delete_vm() {
    local vm="$1"
    ((!INTERACTIVE)) || confirm "Permanently delete VM '$vm' and its disks?" || return 1
    is_off "$vm" || VBoxManage controlvm "$vm" poweroff
    VBoxManage unregistervm "$vm" --delete
}

# --- 1. base ----------------------------------------------------------------

create_base() {
    local iso="$ISO"
    if ((INTERACTIVE)); then
        while true; do
            read -rep "Path to the Windows ISO: " iso
            iso="${iso/#\~/$HOME}"
            [[ -f "$iso" ]] && break
            echo "  not a file: $iso"
        done
    fi
    [[ -n "$iso" ]] || die "no base VM yet — pass --iso <windows.iso>"
    [[ -f "$iso" ]] || die "Windows ISO not found: $iso"

    [[ -f "$AUTOUNATTEND" ]] || die "autounattend not found: $AUTOUNATTEND"
    # Windows Setup ignores an answer file containing raw non-ASCII bytes, and
    # does it silently: setup just prompts for language/keyboard as though no
    # file were attached. Catch it here rather than 20 minutes into an install.
    if LC_ALL=C grep -qP '[^\x00-\x7F]' "$AUTOUNATTEND"; then
        echo "error: $AUTOUNATTEND contains raw non-ASCII characters." >&2
        echo "       Windows Setup would ignore the whole file. Offending lines:" >&2
        LC_ALL=C grep -nP '[^\x00-\x7F]' "$AUTOUNATTEND" >&2
        exit 1
    fi

    # Guest Additions ISO that ships with the installed VirtualBox.
    local ga_iso machine_folder disk src unattend_iso
    ga_iso="$(VBoxManage list systemproperties | sed -n 's/^Default Guest Additions ISO: *//p')"
    machine_folder="$(VBoxManage list systemproperties | sed -n 's/^Default machine folder: *//p')"
    disk="$machine_folder/$BASE_VM/$BASE_VM.vdi"

    # The base is a clean Windows with no samples on it, so clipboard and
    # host-to-guest drop are on here for the manual Defender step. `dfir-vm-network
    # malware` strips both when a clone becomes a detonation box -- that step is
    # what enforces isolation, not this line.
    echo "[*] Creating VM '$BASE_VM' ($RAM MiB, $CPUS vCPU, ${DISK_GB}G disk)"
    VBoxManage createvm --name "$BASE_VM" --ostype Windows11_64 --register
    VBoxManage modifyvm "$BASE_VM" \
        --memory "$RAM" --cpus "$CPUS" --vram 128 \
        --firmware efi --chipset ich9 \
        --graphicscontroller vboxsvga \
        --nic1 nat \
        --clipboard-mode bidirectional --draganddrop hosttoguest \
        --audio-driver none
    # Win11 requirements: vTPM 2.0 + secure boot capable. Bypasses in the
    # autounattend cover hosts where these still trip setup.
    VBoxManage modifyvm "$BASE_VM" --tpm-type 2.0 || echo "  (warning: --tpm-type unsupported; autounattend bypass must cover it)"

    # Windows Setup scans every attached drive's root for autounattend.xml, so it
    # rides in on its own tiny ISO. It lives in the VM's folder, not a temp dir:
    # the VM keeps referencing this drive after the script exits, and clones
    # inherit the reference, so a /tmp path would break both.
    src="$(mktemp -d)"
    cp "$AUTOUNATTEND" "$src/autounattend.xml"
    unattend_iso="$machine_folder/$BASE_VM/unattend.iso"
    xorriso -as mkisofs -quiet -J -R -V UNATTEND -o "$unattend_iso" "$src"
    rm -rf "$src"

    VBoxManage createmedium disk --filename "$disk" --size "$((DISK_GB * 1024))" --format VDI
    VBoxManage storagectl "$BASE_VM" --name SATA --add sata --controller IntelAhci --portcount 4 --bootable on
    VBoxManage storageattach "$BASE_VM" --storagectl SATA --port 0 --device 0 --type hdd --medium "$disk"
    VBoxManage storageattach "$BASE_VM" --storagectl SATA --port 1 --device 0 --type dvddrive --medium "$iso"
    VBoxManage storageattach "$BASE_VM" --storagectl SATA --port 2 --device 0 --type dvddrive --medium "$unattend_iso"
    if [[ -f "$ga_iso" ]]; then
        VBoxManage storageattach "$BASE_VM" --storagectl SATA --port 3 --device 0 --type dvddrive --medium "$ga_iso"
    else
        echo "  (warning: Guest Additions ISO not found at '$ga_iso' — GA install in autounattend will be skipped)"
    fi

    echo "[*] Booting unattended install (the VM powers itself off when done)…"
    VBoxManage startvm "$BASE_VM" --type gui
    wait_poweroff "$BASE_VM" "$INSTALL_TIMEOUT" || die "no snapshot taken; inspect '$BASE_VM' and re-run dfir-lab"
    VBoxManage snapshot "$BASE_VM" take "$SNAPSHOT" \
        --description "clean Windows, UAC off, GA installed"
}

base_stage() {
    echo "== 1/5 Base VM '$BASE_VM'"
    if ! vm_exists "$BASE_VM"; then
        create_base
    elif has_snapshot "$BASE_VM" "$SNAPSHOT"; then
        echo "[=] Exists with a $SNAPSHOT snapshot."
        if decide "Rebuild it from an ISO? (lab VMs already cloned from it are full copies and stay usable)" "$REBUILD"; then
            delete_vm "$BASE_VM" && create_base
        fi
    else
        echo "[!] Exists but has no $SNAPSHOT snapshot (state: $(vm_state "$BASE_VM")) — the install is unfinished or failed."
        local pick=w
        if ((INTERACTIVE)); then
            pick="$(choose "[w]ait for it to power off and snapshot it, [d]elete and recreate, [q]uit?" w d q)"
        elif ((REBUILD)); then
            pick=d
        fi
        case "$pick" in
        w)
            wait_poweroff "$BASE_VM" "$INSTALL_TIMEOUT" || die "no snapshot taken"
            VBoxManage snapshot "$BASE_VM" take "$SNAPSHOT" --description "clean Windows, UAC off, GA installed"
            ;;
        d)
            delete_vm "$BASE_VM" || exit 0
            create_base
            ;;
        q) exit 0 ;;
        esac
    fi
}

# --- 2. Defender ------------------------------------------------------------

# Prints the registry value FLARE's installer keys off, from inside the guest.
guest_defender_disabled() {
    VBoxManage guestcontrol "$BASE_VM" run --username "$GUEST_USER" --password "$GUEST_PASS" \
        -- 'C:\Windows\System32\reg.exe' query 'HKLM\SOFTWARE\Policies\Microsoft\Windows Defender' /v DisableAntiSpyware 2>/dev/null |
        grep -q 'DisableAntiSpyware.*0x1'
}

defender_instructions() {
    cat <<'EOF'

[!] Manual step — the scripts cannot turn Defender off. Tamper Protection is
    kernel-enforced (no answer file, registry write or PowerShell call gets
    past it), and FLARE refuses to install while Defender is live. In the guest:

  1. Windows Security > Virus & threat protection > Manage settings
     > Tamper Protection: Off. This is the only GUI-only step: while it is on,
     every policy below is silently ignored.
  2. Disable Defender by Group Policy. Win+R > gpedit.msc > Computer
     Configuration > Administrative Templates > Windows Components >
     Microsoft Defender Antivirus:
       - "Turn off Microsoft Defender Antivirus"                -> Enabled
       - Real-time Protection > "Turn off real-time protection" -> Enabled
     Then in an admin prompt: gpupdate /force
     (Real-time off alone does NOT count: Defender re-enables it and FLARE
     keeps reporting "Windows Defender Disabled: False".)
     No gpedit (Home edition)? Set the same policy values from admin PowerShell:
       $p = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender"
       New-Item "$p\Real-Time Protection" -Force | Out-Null
       Set-ItemProperty $p DisableAntiSpyware 1 -Type DWord
       Set-ItemProperty "$p\Real-Time Protection" DisableRealtimeMonitoring 1 -Type DWord
  3. Reboot the guest (the policy only applies after a restart) and leave it
     running at the desktop.

EOF
}

# Shut the base down and re-take BUILD-READY with the "Defender off" marker.
defender_snapshot() {
    echo "[*] Shutting the guest down and re-taking $SNAPSHOT"
    VBoxManage controlvm "$BASE_VM" acpipowerbutton
    wait_poweroff "$BASE_VM" 600 || die "'$BASE_VM' did not power off; shut it down and re-run dfir-lab"
    VBoxManage snapshot "$BASE_VM" delete "$SNAPSHOT"
    VBoxManage snapshot "$BASE_VM" take "$SNAPSHOT" --description "$DEFENDER_OFF"
}

defender_done() { [[ "$(base_snapshot_desc "$BASE_VM")" == "$DEFENDER_OFF" ]]; }

defender_stage() {
    echo "== 2/5 Defender off on the base"
    has_snapshot "$BASE_VM" "$SNAPSHOT" || die "no base '$BASE_VM'@$SNAPSHOT yet — run the base stage first"
    if defender_done; then
        echo "[=] Already done ($SNAPSHOT is marked '$DEFENDER_OFF')."
        return
    fi
    # Flag mode is one pass: verify if the human already did it, otherwise
    # hand over and exit 3 so the caller knows to come back.
    if ((!INTERACTIVE)) && ! is_off "$BASE_VM" && guest_defender_disabled; then
        echo "[+] Guest reports DisableAntiSpyware = 1."
        defender_snapshot
        return
    fi
    if is_off "$BASE_VM"; then VBoxManage startvm "$BASE_VM" --type gui; fi
    defender_instructions
    if ((!INTERACTIVE)); then
        echo "[!] Waiting on a human. Once the guest is back up after step 3, re-run: dfir-lab --defender"
        exit 3
    fi
    while true; do
        read -rp "Press Enter when the guest is back up after the reboot… "
        if guest_defender_disabled; then
            echo "[+] Guest reports DisableAntiSpyware = 1."
            break
        fi
        echo "[!] Could not confirm DisableAntiSpyware = 1 in the guest (not set yet, or Guest Additions not up)."
        confirm "Try again?" || die "Defender step not done; re-run dfir-lab when it is"
    done
    defender_snapshot
}

# --- 3-5. per variant ---------------------------------------------------------

# The base is a single VM, but each variant's build wants its own VM
# (variants/*.yaml VM_NAME) carrying its own BUILD-READY snapshot, and reads
# its FLARE config from the fixed $REQUIRED_FILES/config.xml.
prepare_variant() {
    local variant="$1" vm="$2"
    local config_xml="$DFIR_DIR/config/$variant-config.xml"
    local manifest="$DFIR_DIR/manifests/$variant-tools.yaml"
    for f in "$config_xml" "$manifest"; do [[ -f "$f" ]] || die "missing $f"; done

    if ! vm_exists "$vm"; then
        echo "[*] Cloning $BASE_VM@$SNAPSHOT -> $vm"
        # --mode machine clones only the snapshot's state: the clone has no
        # snapshots of its own, so the build's restore would fail without the
        # re-take below.
        VBoxManage clonevm "$BASE_VM" --snapshot "$SNAPSHOT" --mode machine \
            --name "$vm" --register
    fi
    if ! has_snapshot "$vm" "$SNAPSHOT"; then
        echo "[*] Taking $SNAPSHOT on $vm"
        VBoxManage snapshot "$vm" take "$SNAPSHOT" --description "clean Windows base for $variant"
    fi

    # The build copies this directory into the guest Desktop, then runs
    # install.ps1 with -customConfig '<Desktop>\config.xml' -customLayout
    # '<Desktop>\LayoutModification.xml'. Only our managed filenames are
    # written, so anything else you keep here survives. It is shared by both
    # variants, which is why staging happens right before each build.
    echo "[*] Staging FLARE inputs in $REQUIRED_FILES"
    mkdir -p "$REQUIRED_FILES"
    install -m644 "$config_xml" "$REQUIRED_FILES/config.xml"
    # No comments in that file: Windows 11 silently drops every taskbar pin if
    # anything sits between <?xml?> and the root element. File Explorer is
    # pinned by app ID; the others by .lnk (TOOL_LIST_DIR spelled out).
    install -m644 "$DFIR_DIR/windows/LayoutModification.xml" "$REQUIRED_FILES/LayoutModification.xml"
    install -m644 "$DFIR_DIR/windows/update-tools.ps1" "$REQUIRED_FILES/update-tools.ps1"
    # Colemak-SE: the custom-item runs the script; its folder stays as a manual fallback.
    install -m644 "$DFIR_DIR/windows/set-colemak-se.ps1" "$REQUIRED_FILES/set-colemak-se.ps1"
    rm -rf "$REQUIRED_FILES/colemak-se" "$REQUIRED_FILES/se-cmak_amd64.msi" # latter: pre-folder layout
    cp -rL --no-preserve=mode "$DFIR_DIR/windows/colemak-se" "$REQUIRED_FILES/colemak-se"
    install -m644 "$manifest" "$REQUIRED_FILES/tools.yaml" # update-tools.ps1's default
}

variant_stage() {
    local variant="$1" yaml="$DFIR_DIR/variants/$1.yaml" vm exported built=""
    [[ -f "$yaml" ]] || die "missing $yaml"
    vm="$(sed -n 's/^VM_NAME: *//p' "$yaml")"
    exported="$(sed -n 's/^EXPORTED_VM_NAME: *//p' "$yaml")"
    [[ -n "$vm" && -n "$exported" ]] || die "VM_NAME/EXPORTED_VM_NAME missing in $yaml"
    defender_done || die "base '$BASE_VM' is not marked Defender-off — run the base and Defender stages first"

    echo "== 3/5 [$variant] VM '$vm'"
    if vm_exists "$vm"; then
        # vbox-build-flare-vm names its post-install snapshot <EXPORTED>.<YYYYMMDD>.base.
        built="$(snapshot_names "$vm" | grep -E "^${exported//./\\.}\.[0-9]{8}\.base$" | sort | tail -n1 || true)"
        echo "[=] Exists (state: $(vm_state "$vm"); last build: ${built:-none})."
        is_off "$vm" || die "'$vm' is running — a build may be in progress. Shut it down first."
        local pick=k
        if ((INTERACTIVE)); then
            if [[ -n "$built" ]]; then
                pick="$(choose "[f]inish from $built (skips the FLARE install), [k]eep it and rebuild from its $SNAPSHOT, [r]eclone from the base (deletes it), [s]kip $variant?" f k r s)"
            else
                pick="$(choose "[k]eep it (a rebuild restores its $SNAPSHOT), [r]eclone from the base (deletes it), [s]kip $variant?" k r s)"
            fi
        elif ((RECLONE)); then
            pick=r
        elif ((RESUME)); then
            [[ -n "$built" ]] || die "--resume: '$vm' has no $exported.<date>.base snapshot to finish from"
            pick=f
        fi
        case "$pick" in
        r)
            delete_vm "$vm" || return 0
            built=""
            ;;
        s) return 0 ;;
        k) built="" ;;
        esac
    fi
    prepare_variant "$variant" "$vm"

    echo "== 4/5 [$variant] FLARE build"
    if [[ -n "$built" ]]; then
        # Upstream's resume path: restore <EXPORTED>.<date>.base and redo only
        # the per-snapshot steps + export. --date must match that snapshot's.
        local date="${built#"$exported".}"
        vbox-build-flare-vm "$yaml" --do-not-install-flare-vm --date "${date%.base}"
    elif decide "Build '$vm' now? (FLARE's install takes a few hours)" "$BUILD"; then
        vbox-build-flare-vm "$yaml" --custom_config
        local logs="$HOME/.local/state/dfir/flare-vm-logs"
        echo "    Failed packages do not fail the build — check $logs/flare-vm-failed_packages.txt"
        # VM-Apply-Configurations logs its one catch-all error and carries on,
        # dropping every config section after the one that threw. Only
        # [installer.vm] applies our config.xml; debloat.vm runs the same
        # function over upstream's own debloat config, whose errors are not ours.
        if grep -F "An error occurred while applying config" "$logs/flare-vm-log.txt" 2>/dev/null | grep -F "[installer.vm]"; then
            echo "[!] FLARE's config step failed (above), so later config sections — custom-items like Colemak-SE and the taskbar — did not run."
        fi
    elif [[ "$variant" == malware ]]; then
        echo "[!] Not built. Before any detonation run: dfir-vm-network malware '$vm'"
        return 0
    fi

    echo "== 5/5 [$variant] Network trust model"
    # Upstream's build exits 0 even when it bails out, so check state rather
    # than its exit code before touching settings.
    if is_off "$vm"; then
        dfir-vm-network "$variant" "$vm"
    else
        echo "[!] '$vm' is still running, so network settings were not applied. Once it is off:"
        echo "    dfir-vm-network $variant '$vm'"
    fi
}

# --- main ---------------------------------------------------------------------

status() {
    local variant vm
    echo "base=$BASE_VM exists=$(vm_exists "$BASE_VM" && echo yes || echo no)"
    if vm_exists "$BASE_VM"; then
        echo "base_state=$(vm_state "$BASE_VM")"
        echo "base_snapshot=$(has_snapshot "$BASE_VM" "$SNAPSHOT" && echo yes || echo no)"
        echo "base_defender_off=$(defender_done && echo yes || echo no)"
    fi
    for variant in dfir malware; do
        vm="$(sed -n 's/^VM_NAME: *//p' "$DFIR_DIR/variants/$variant.yaml")"
        echo "${variant}_vm=$vm exists=$(vm_exists "$vm" && echo yes || echo no)"
        if vm_exists "$vm"; then
            echo "${variant}_state=$(vm_state "$vm")"
            echo "${variant}_snapshots=$(snapshot_names "$vm" | paste -sd, -)"
        fi
    done
}

command -v VBoxManage >/dev/null || die "VBoxManage not found — is cyber.dfir.enable set and are you in vboxusers?"

if ((!INTERACTIVE)); then
    if ((STATUS)); then
        status
        exit 0
    fi
    ((DO_BASE || DO_DEFENDER || ${#VARIANTS[@]})) || usage 1
    if ((DO_BASE)); then base_stage; fi
    if ((DO_DEFENDER)); then defender_stage; fi
    for v in "${VARIANTS[@]}"; do variant_stage "$v"; done
    echo "[+] Done."
    exit 0
fi

base_stage
defender_stage

case "$(choose "Build which lab VM? [d]fir, [m]alware, [b]oth, [n]one:" d m b n)" in
d) variant_stage dfir ;;
m) variant_stage malware ;;
b)
    variant_stage dfir
    variant_stage malware
    ;;
n) ;;
esac
echo "[+] Done."
